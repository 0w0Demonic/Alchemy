#Requires AutoHotkey v2

/**
 * A structure of objects that "cascade" similar to CSS selectors. Works
 * perfectly for context-based theme settings, which was the original intent
 * behind writing this class.
 * 
 * Objects inside this structure fall back to their sibling objects with
 * the same name, e.g. `Theme.Button.Font` inherits from `Theme.Font` (see
 * below) and then, finally, the top-most enclosing object (i.e. `Theme`).
 * 
 * @example
 * Theme := {
 *     Button: {
 *         Font: { ; this object...
 *             Name: "Cascadia Code" ; pun not intended - literally best font
 *         }
 *     },
 *     Font: { ; inherits from this object!
 *         Size: 12
 *     }
 *     Opt: "..."
 * }
 * Cascade.Transform(Theme) ; alternatively: `Theme := Cascade.Create(Theme)`
 * 
 * Font := Theme.Button.Font
 * MsgBox(Font.Name) ; "Cascadia Code"
 * MsgBox(Font.Size) ; 12
 * 
 * @description
 * In the example above, `Theme.Button.Font` inherits its values from
 * `Theme.Font`, and then from `Theme`.
 * 
 * There are two ways to create cascading objects. You have the option to create
 * a deep clone (`Cascade.Create(Obj)`) or to transform the given object in
 * place (`Cascade.Transform(Obj)`).
 * 
 * @example
 * Theme := { ... }
 * 
 * Obj := Cascade.Create(Theme) ; create a clone
 * Cascade.Transform(Theme)     ; change in place
 * 
 * @description
 * You can create cascades of classes by using the `ClassCascade` subtype.
 * It additionally overrides the prototypes of each class to be connected.
 * 
 * Using `ClassCascade` as base class will automatically call `.Transform()` to
 * enable cascading behavior. As an alternative, you can use
 * `ClassCascade.Transform(Cls)` or `ClassCascade.Create(Cls)` instead.
 * 
 * @example
 * ; class is automatically `.Transform()`-ed when loaded
 * class Theme extends ClassCascade {
 *     class Button {
 *         class Font {
 *             Name => "Cascadia Code"
 *         }
 *     }
 *     class Font {
 *         Size => 12
 *     }
 * }
 * ButtonTheme := Theme.Button
 * Font := ButtonTheme.Font()
 * MsgBox(ButtonTheme.Size) ; 12
 * 
 * @author 0w0Demonic
 */
class Cascade {
    /**
     * Enables cascading behavior on the given object in place.
     * 
     * @param   {Object}  Obj  any object
     * @return  {Object}
     */
    static Transform(Obj) {
        if (!IsObject(Obj)) {
            throw TypeError("Expected an Object",, Type(Obj))
        }

        Seen := Map()
        Seen.CaseSense := false
        OverridePrototypes := (this == ClassCascade
                    || HasBase(this, ClassCascade))

        Traverse(Obj, Seen, OverridePrototypes, true)
        return Obj

        static Traverse(Obj, Seen, OverridePrototypes, IsRoot) {
            for Key, Value in ObjOwnProps(Obj) {
                if (!IsSet(Value) || !IsObject(Value)) {
                    continue
                }
                if (OverridePrototypes
                        && (Value is Class)
                        && Key == "Prototype") {
                    continue
                }
                switch {
                    case IsRoot:        Base := Obj
                    case Seen.Has(Key): Base := Seen.Get(Key)
                    default:
                        Seen.Set(Key, Value)
                        continue
                }
                ObjSetBase(Value, Base)
                if (OverridePrototypes
                        && (Value is Class) && (Base is Class)
                        && ObjHasOwnProp(Value, "Prototype")
                        && ObjHasOwnProp(Base, "Prototype")) {
                    ObjSetBase(Value.Prototype, Base.Prototype)
                }
                Seen.Set(Key, Value)
            }

            for Key, Value in ObjOwnProps(Obj) {
                if (!IsSet(Value) || !IsObject(Value)) {
                    continue
                }
                if ((Value is Class) && Key == "Prototype") {
                    continue
                }
                Traverse(Obj.%Key%, Seen.Clone(), OverridePrototypes, false)
            }
        }
    }

    /**
     * Returns a deep clone of the object, augmented with cascading behavior.
     * 
     * @param   {Object}  Obj  any object
     * @return  {Object}
     */
    static Create(Obj) {
        static Define := (Object.Prototype.DefineProp)
        static Clone  := (Object.Prototype.Clone)

        if (!IsObject(Obj)) {
            throw TypeError("Expected an Object",, Type(Obj))
        }

        Seen := Map()
        Seen.CaseSense := false
        OverridePrototypes := (this == ClassCascade
                    || HasBase(this, ClassCascade))

        Result := Object()
        ObjSetBase(Result, Cascade.Prototype)
        return Traverse(Obj, Result, Seen, OverridePrototypes, true)

        Traverse(Obj, Result, Seen, OverridePrototypes, IsRoot) {
            for Key, Value in ObjOwnProps(Obj) {
                if (OverridePrototypes
                        && (Obj is Class)
                        && (Key == "Prototype")) {
                    continue
                }
                if (!IsSet(Value)) {
                    continue
                }

                ClonedValue := (IsObject(Value) ? Clone(Value) : Value)
                Define(Result, Key, { Value: ClonedValue })

                if (!IsObject(Value)) {
                    continue
                }

                switch {
                    case IsRoot:        Base := Obj
                    case Seen.Has(Key): Base := Seen.Get(Key)
                    default:
                        Seen.Set(Key, ClonedValue)
                        continue
                }

                ObjSetBase(ClonedValue, Base)
                if (OverridePrototypes
                        && (ClonedValue is Class) && (Base is Class)
                        && ObjHasOwnProp(ClonedValue, "Prototype")
                        && ObjHasOwnProp(Base, "Prototype")) {
                    ObjSetBase(ClonedValue.Prototype, Base.Prototype)
                }
                Seen.Set(Key, ClonedValue)
            }

            for Key, Value in ObjOwnProps(Obj) {
                if ((Obj is Class) && (Key == "Prototype")) {
                    continue
                }
                if (!IsSet(Value) || !IsObject(Value)) {
                    continue
                }
                Traverse(Obj.%Key%,
                         Result.%Key%,
                         Seen.Clone(),
                         OverridePrototypes,
                         false)
            }
            return Result
        }
    }
}

/**
 * A variant of {@link Cascade} designed for classes.
 * 
 * `ClassCascade` allows entire classes to support cascading behavior,
 * including their prototypes.
 * 
 * Using `ClassCascade` as base class automatically enables cascading by
 * applying `.Transform()`. Alternatively, you can use
 * `ClassCascade.Transform(Cls)` and `ClassCascade.Create(Cls)` instead.
 */
class ClassCascade extends Cascade {
    /** Static init. */
    static __New() {
        if (this == ClassCascade) {
            return
        }
        this.Transform(this)
    }
}

/** Example that uses `CascadingClass` to define a theme object. */
class Theme extends ClassCascade {
    class Button {
        class Font {
            Name => "Cascadia Code"
        }
    }
    class Font {
        Size => 12
    }
}

if (A_LineFile == A_ScriptFullPath) {
    ButtonTheme := Theme.Button
    Font := ButtonTheme.Font()
    FormatStr := "
    (
    Font name: {}
    - defined by: Theme.Button.Font.Prototype.Name.Get

    Font size: {}
    - defined by: Theme.Font.Prototype.Size.Get
    )"
    Output := Format(FormatStr, Font.Name, Font.Size)
    MsgBox(Output, "Cascade.ahk - TEST #1")
}
