#Requires AutoHotkey v2.0

/**
 * A structure of objects that "cascade" similar to CSS selectors. Works
 * perfectly for context-based theme settings, which was the original intent
 * behind writing this class.
 * 
 * Objects inside this structure fall back to their enclosing objects.
 * 
 * @example
 * Theme := {
 *     Button: {
 *         font_size: 12
 *     },
 *     font_name: "Cascadia Code" ; pun not intended
 * }
 * 
 * MsgBox(Theme.Button.font_size) ; 12
 * MsgBox(Theme.Button.font_name) ; "Cascadia Code"
 * 
 * @description
 * You can create a cascading object by:
 * - {@link Cascade.Transform transforming an object}
 * - {@link Cascade.Create creating a deep clone of an object}
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
 *         font_name => "Cascadia Code"
 *     }
 *     font_size => 12
 * }
 * 
 * ButtonTheme := Theme.Button()
 * MsgBox(ButtonTheme.font_name) ; "Cascadia Code"
 * MsgBox(ButtonTheme.font_size) ; 12
 * 
 * @author 0w0Demonic
 */
class Cascade {
    /**
     * Standard constructor that defaults to `.Transform()`.
     * 
     * @param   {Object}  Obj  any object
     * @return  {Object}
     */
    static Call(Obj) => this.Transform(Obj)

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
        AsClass := (this == ClassCascade || HasBase(this, ClassCascade))
        if (AsClass && !(Obj is Class)) {
            throw TypeError("Expected a Class",, Type(Obj))
        }

        Traverse(Obj, AsClass)
        return Obj

        /**
         * Traverses the object recursively, changing the base of each nested
         * object to its enclosing object.
         * 
         * @param   {Object}   Obj      the object to be traversed
         * @param   {Boolean}  AsClass  whether prototypes should be overridden
         */
        static Traverse(Obj, AsClass) {
            for Key, Value in ObjOwnProps(Obj) {
                if (!IsSet(Value) || !IsObject(Value)) {
                    continue
                }
                if (AsClass && (Obj is Class) && (Key == "Prototype")) {
                    continue
                }
                ObjSetBase(Value, Obj)
                if (AsClass && (Value is Class)
                            && (ObjHasOwnProp(Value, "Prototype"))) {
                    ObjSetBase(Value.Prototype, Obj.Prototype)
                }
                Traverse(Value, AsClass)
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

        AsClass := (this == ClassCascade) || HasBase(this, ClassCascade)
        if (AsClass && !(Obj is Class)) {
            throw TypeError("Expected a Class",, Type(Obj))
        }

        Result := Object()
        ObjSetBase(Result, Cascade.Prototype)
        Traverse(Obj, Result, AsClass)
        return Result

        /**
         * Traverses the object recursively, creating a values-only deep clone
         * of the object in the process.
         * 
         * @param   {Object}   Obj      object to be traversed
         * @param   {Object}   Result   output object
         * @param   {Boolean}  AsClass  whether prototypes should be overridden
         */
        static Traverse(Obj, Result, AsClass) {
            for Key, Value in ObjOwnProps(Obj) {
                if (!IsSet(Value)) {
                    continue
                }
                if (AsClass && (Obj is Class) && (Key == "Prototype")) {
                    continue
                }
                if (!IsObject(Value)) {
                    Define(Result, Key, { Value: Value })
                    continue
                }
                ClonedValue := Clone(Value)
                ObjSetBase(ClonedValue, Result)
                if (AsClass && (ClonedValue is Class)
                            && ObjHasOwnProp(ClonedValue, "Prototype")
                            && ObjHasOwnProp(Result, "Prototype")) {
                    ObjSetBase(ClonedValue.Prototype, Result.Prototype)
                }
                Define(Result, Key, { Value: ClonedValue })
                Traverse(Obj.%Key%, Result.%Key%, AsClass)
            }
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
 * applying `.Transform()` to itself. Alternatively, you can use either
 * `ClassCascade.Transform(Cls)` or `ClassCascade.Create(Cls)`.
 */
class ClassCascade {
    static __New() => (this == ClassCascade) || this.Transform(this)
}