#Requires AutoHotkey v2.0

/**
 * This utility introduces simulated public and private properties into
 * AutoHotkey classes. It works seamlessly, without changing how you
 * normally interact with objects.
 * 
 * ```ahk
 * class Foo {
 *     ; private field
 *     static _value := "private"
 * 
 *     ; public method
 *     static GetValue() => this._value
 * }
 * Privatizer.Transform(Foo)
 * MsgBox(Foo.GetValue())     ; "private"
 * MsgBox(Foo._value)         ; Error! ... has no property named `_value`.
 * ```
 * 
 * Private properties start with *exactly one underscore*, e.g. `_foo`.
 * These can only be accessed from inside the class itself, i.e. when
 * called from a property that is intrinsic to the class.
 * 
 * ---
 * 
 * You can convert your classes by either
 * - extending `Privatizer`
 * - calling `Privatizer.Transform(TargetClass)`
 * 
 * ```ahk
 * ; option 1
 * class Foo extends Privatizer {
 * }
 * 
 * ; option 2
 * class Bar {
 * }
 * 
 * Privatizer.Transform(Bar)
 * ```
 * 
 * ---
 * 
 * ### How it works (Behind The Scenes)
 * 
 * To support the use of private properties, this utility...
 * - generates a new class that derives from the targeted class;
 * - moves all private properties
 * - wraps public properties (i.e.: everything else) to temporarily "elevate"
 *   to the subclass.
 * 
 * Where's an example of what you can imagine is done to the class
 * after conversion:
 * 
 * ```ahk
 * ; before conversion
 * 
 * class Example extends Privatizer {
 *     static _secret := "private"
 * 
 *     static GetSecret() {
 *         return this._secret
 *     }
 * }
 * 
 * ; > > > > > > > > > > > > > > > > > > > > > > > > > > > > > > > > > 
 * ; after conversion
 * 
 * ; "public class"
 * class Example {
 *     static GetSecret() {
 *         return Example_Private._secret
 *     }
 * }
 * 
 * ; "private class", which is newly generated and inaccessible
 * class Example_Private {
 *     static _secret := "private"
 * }
 * ```
 * 
 * ---
 * 
 * ### Best Practices
 * 
 * Although a converted class ends up fairly bullet-proof, there's some
 * things that might still cause it to break:
 * 
 * - *Don't override the base or the property of your class:*
 * 
 *   This utility requires the base class and the prototype to remain the same.
 *   Changing them might cause properties to break.
 * 
 * - *Be cautious with `.DefineProp()`:*
 * 
 *   Privatized classes have their own `.DefineProp()` and `.__Set()`
 *   properties so that they can handle new incoming properties appropriately.
 *   You should always call the custom `.DefineProp()` method instead of using
 *   e.g. `({}.DefineProp)(Obj, ...)` directly.
 * 
 *   In other words, *code like a normal human being*. Lol.
 * 
 * @author 0w0Demonic
 * Made with lots of love, caffeine, and alcohol.
 */
class Privatizer {
    /**
     * Static constructor that automatically converts a class if it derives
     * from `Privatizer`.
     * 
     * @example
     * class Foo extends Privatizer {
     *     ; ...
     * }
     */
    static __New() {
        if (this != Privatizer) {
            ObjSetBase(this, Object)
            ObjSetBase(this.Prototype, Object.Prototype)
            Privatizer.Transform(this)
        }
    }

    /**
     * Converts the given class to support public and private properties.
     * 
     * @param   {Class}  Target  the class to be converted
     */
    static Transform(Target) {
        if (!(Target is Class)) {
            throw TypeError("Expected a Class",, Type(Target))
        }

        BaseClass     := Target
        BaseProto     := BaseClass.Prototype
        BaseClassName := BaseProto.__Class
        SubclassName  := BaseClassName . "(private)"

        Debug("######## Privatizing class: '{1}' ########", BaseClassName)
        Debug("")
        Debug("creating subclass:")
        Debug("    class {1} extends {2} {", SubclassName, BaseClassName)
        Debug("        ...")
        Debug("    }")

        Subclass := CreateSubclass(BaseClass, SubclassName)
        SubProto := Subclass.Prototype

        Debug("done.")
        Debug("")

        Debug("defining '{1}.__Set()'", BaseClassName)
        Define(BaseClass, "__Set", StaticMetaSetter(BaseClass, Subclass))

        Debug("defining '{1}.Prototype.__Set()'", BaseClassName)
        Define(BaseProto, "__Set", MetaSetter(BaseClass, Subclass))

        Debug("done.")
        Debug("")

        Public       := BaseClass
        Private      := Subclass
        PublicProto  := BaseClass.Prototype
        PrivateProto := Subclass.Prototype

        Debug("modifying static properties ({1}):", BaseClassName)
        for PropName, PropDesc in FindProps(BaseClass, "__Set") {
            PropDesc := ConvertStaticProp(PropName, PropDesc, Public, Private)
            Define(Public, PropName, PropDesc)
        }
        Debug("done.")
        Debug("")

        Debug("modifying instance properties ({1}.Prototype)", BaseClassName)
        for PropName, PropDesc in FindProps(BaseProto, "__Set") {
            PropDesc := ConvertInstanceProp(PropName, PropDesc, Public, Private)
            Define(PublicProto, PropName, PropDesc)
        }
        Debug("done.")
        Debug("")

        Debug("defining '{1}.DefineProp()'", BaseClassName)
        Define(BaseClass, "DefineProp",
                CreateStaticDefineProp(BaseClass, Subclass))

        Debug("defining '{1}.Prototype.DefineProp()'", BaseClassName)
        Define(BaseProto, "DefineProp",
                CreateDefineProp(BaseClass, Subclass))

        Debug("done.")
        Debug("----------------------------------------------")
        return

; >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

        ; >>
        ; >>>>>>>> MISC >>>>>>>>
        ; >>

        /**
         * `Object.Prototype.DefineProp()`.
         * 
         * @param   {Object}  Obj           any object
         * @param   {String}  PropertyName  name of the property
         * @param   {Object}  PropDesc      property descriptor
         * @return  {Object}
         */
        static Define(Obj, PropName, PropDesc) {
            return (Object.Prototype.DefineProp)(Obj, PropName, PropDesc)
        }

        /**
         * `Object.Prototype.DeleteProp()`.
         * 
         * @param   {Object}  Obj           any object
         * @param   {String}  PropertyName  name of the property
         * @return  {Object}
         */
        static Delete(Obj, PropName) {
            return (Object.Prototype.DeleteProp)(Obj, PropName)
        }

        /**
         * `Object.Prototype.GetOwnPropDesc()`.
         * 
         * @param   {Object}  Obj           any object
         * @param   {String}  PropertyName  name of the property
         * @return  {Object}
         */
        static GetProp(Obj, PropName) {
            return (Object.Prototype.GetOwnPropDesc)(Obj, PropName)
        }

        /**
         * Debug output (absolutely life-saving).
         * 
         * @param   {String}  FormatString  format string to be used
         * @param   {Any*}    Args          zero or more arguments
         */
        static Debug(FormatString, Args*) {
            static Output := (
                OutputDebug                                     ; to debugger
;               ObjBindMethod(FileAppend,, unset, "debug.log")  ; to file
;               (*) => false                                    ; do nothing
            )

            Str := Format("[DEBUG] " . FormatString . "`r`n", Args*)
            Output(Str)
        }

        /**
         * Debug output related to conversion of properties.
         * 
         * @param   {String}  Description  description of the new property
         * @param   {String}  PropName     name of the property
         */
        static DebugProp(Description, PropName) {
            Debug("    {1:-20} : {2}", Description, PropName)
        }

        ; >>
        ; >>>>>>>> SUBCLASS GENERATION >>>>>>>>
        ; >>

        /**
         * Generates a new subclass that derives from the given base class.
         * 
         * @param   {Class?}   BaseClass  subclass to derive from
         * @param   {String?}  Name       name of the class (`__Class`)
         */
        static CreateSubclass(BaseClass := Object, Name := "") {
            static DoNothing := { Call: (*) => false }

            if (!(BaseClass is Class)) {
                throw TypeError("Expected a Class",, Type(BaseClass))
            }

            if (VerCompare(A_AhkVersion, "2.1-alpha.3") >= 0) {
                ; prevent `static __New()` from being called when creating
                ; a subclass through `Class()`
                if (ObjHasOwnProp(BaseClass, "__New")) {
                    __New := GetProp(BaseClass, "__New")
                    Define(BaseClass, "__New", DoNothing)
                    Subclass := Class(BaseClass)
                    Define(BaseClass, "__New", __New)
                } else {
                    Define(BaseClass, "__New", DoNothing)
                    Subclass := Class(BaseClass)
                    Delete(BaseClass, "__New")
                }
            } else {
                Subclass := Class()
                Subclass.Prototype := Object()
                ObjSetBase(Subclass, BaseClass)
                ObjSetBase(Subclass.Prototype, BaseClass.Prototype)
            }
            Subclass.Prototype.__Class := Name
            return Subclass
        }

        ; >>
        ; >>>>>>>> CONVERSION >>>>>>>>
        ; >>

        /**
         * Enumerates all properties of the given object, returning a map
         * of property names mapped to their property descriptor.
         * 
         * @param   {Object}   Target        any object
         * @param   {String*}  ExcludedProp  properties to be ignored
         * @return  {Map}
         */
        static FindProps(Target, ExcludedProps*) {
            M := Map()
            M.CaseSense := false
            for PropName in ObjOwnProps(Target) {
                M.Set(PropName, GetProp(Target, PropName))
            }
            for ExcludedProp in ExcludedProps {
                if (M.Has(ExcludedProp)) {
                    M.Delete(ExcludedProp)
                }
            }
            return M
        }

        /**
         * Converts a static property of the user-defined class.
         * 
         * @param   {String}  PropName  name of the property
         * @param   {Object}  PropDesc  the property descriptor
         * @param   {Class}   Public    public class
         * @param   {Class}   Private   private class
         * @return  {Object}
         */
        static ConvertStaticProp(PropName, PropDesc, Public, Private) {
            switch {
                case (IsPrivate(PropName) && IsField(PropDesc)):
                    Convert     := PrivateField
                    Description := "private field"
                case (IsPrivate(PropName)):
                    Convert     := PrivateStaticProp
                    Description := "private"
                default:
                    Convert     := PublicStaticProp
                    Description := "public"
            }
            DebugProp(Description, PropName)
            return Convert(PropName, PropDesc, Public, Private)
        }

        /**
         * Converts an instance property of the user-defined class.
         * 
         * @param   {String}  PropName  name of the property
         * @param   {Object}  PropDesc  the property descriptor
         * @param   {Class}   Public    public class
         * @param   {Class}   Private   private class
         * @return  {Object}
         */
        static ConvertInstanceProp(PropName, PropDesc, Public, Private) {
            switch {
                case (!IsPrivate(PropName)):
                    Convert     := PublicProp
                    Description := "public property"
                case (IsField(PropDesc)):
                    Convert     := PrivateField
                    Description := "private field"
                default:
                    Convert     := PrivateProp
                    Description := "private field"
            }
            DebugProp(Description, PropName)
            return Convert(PropName, PropDesc, Public, Private)
        }

        ; >>
        ; >>>>>>>> PROPERTIES >>>>>>>>
        ; >>

        /**
         * Determines whether the property name is public or private.
         * 
         * @param   {String}  PropName  name of the property
         * @return  {Boolean}
         */
        static IsPrivate(PropName) => (PropName ~= "^_[^_]")

        /**
         * Determines whether the property descriptor is a regular field with
         * `Value` property.
         * 
         * @param   {Object}  PropDesc  the property descriptor
         * @return  {Boolean}
         */
        static IsField(PropDesc) => ObjHasOwnProp(PropDesc, "Value")

        /**
         * Helper function that wraps a property descriptor by applying the
         * given `Decorator` function.
         * 
         * @param   {Object}  PropDesc   the property descriptor
         * @param   {Func}    Decorator  decorator function
         * @return  {Object}
         */
        static DecorateProp(PropDesc, Decorator) {
            if (IsField(PropDesc)) {
                return PropDesc
            }
            Result := Object()
            for Descriptor in Array("Get", "Set", "Call") {
                if (ObjHasOwnProp(PropDesc, Descriptor)) {
                    Decorated := Decorator(GetProp(PropDesc, Descriptor).Value)
                    Define(Result, Descriptor, { Value: Decorated })
                }
            }
            return Result
        }
        
        /**
         * Represents a public static property. Conceptually speaking, each
         * public static property "impersonates" as the subclass to gain access
         * to hidden private properties.
         * 
         * @param   {String}  PropName  name of the property
         * @param   {Object}  PropDesc  the property descriptor
         * @param   {Class}   Public    public class
         * @param   {Class}   Private   private class
         * @return  {Object}
         */
        static PublicStaticProp(PropName, PropDesc, Public, Private) {
            return DecorateProp(PropDesc, Impersonation)

            Impersonation(Callback) {
                return Impersonated

                Impersonated(_, Args*) {
                    return Callback(Private, Args*)
                }
            }
        }

        /**
         * Represents a private static property. Additional type checking is
         * done to ensure the property was called with elevated rights.
         * 
         * @param   {String}  PropName  name of the property
         * @param   {Object}  PropDesc  the property descriptor
         * @param   {Class}   Public    public class
         * @param   {Class}   Private   private class
         * @return  {Object}
         */
        static PrivateStaticProp(PropName, PropDesc, Public, Private) {
            return DecorateProp(PropDesc, TypeChecking)

            TypeChecking(Callback) {
                return TypeChecked

                TypeChecked(this, Args*) {
                    if (this != Private) {
                        throw TypeError("private property", -2, PropName)
                    }
                    return Callback(this, Args*)
                }
            }
        }

        /**
         * Represents a public instance property. The property temporarily
         * "elevates" itself to the subclass to gain access to internal
         * properties.
         * 
         * @param   {String}  PropName  name of the property
         * @param   {Object}  PropDesc  the property descriptor
         * @param   {Class}   Public    public class
         * @param   {Class}   Private   private class
         * @return  {Object}
         */
        static PublicProp(PropName, PropDesc, Public, Private) {
            return DecorateProp(PropDesc, Elevation)

            Elevation(Callback) {
                return Elevated

                Elevated(this, Args*) {
                    Prev := ObjGetBase(this)
                    ObjSetBase(this, Private.Prototype)
                    try {
                        Result := Callback(this, Args*)
                        ObjSetBase(this, Prev)
                        return Result
                    } catch as Ex {
                        ObjSetBase(this, Prev)
                        throw Ex
                    }
                }
            }
        }

        /**
         * Represents a private instance property. Additional type checking is
         * done to ensure the property was called with elevated rights.
         * 
         * @param   {String}  PropName  name of the property
         * @param   {Object}  PropDesc  the property descriptor
         * @param   {Class}   Public    public class
         * @param   {Class}   Private   private class
         * @return  {Object}
         */
        static PrivateProp(PropName, PropDesc, Public, Private) {
            return DecorateProp(PropDesc, TypeChecking)

            TypeChecking(Callback) {
                return TypeChecked

                TypeChecked(this, Args*) {
                    if (!(this is Private)) {
                        throw TypeError("private property", -2, PropName)
                    }
                    return Callback(this, Args*)
                }
            }
        }

        /**
         * Represents a regular field, but with additional type checking.
         * 
         * @param   {String}  PropName  name of the property
         * @param   {Object}  PropDesc  the property descriptor
         * @param   {Class}   Public    public class
         * @param   {Class}   Private   private class
         * @return  {Object}
         */
        static PrivateField(PropName, PropDesc, Public, Private) {
            Value := PropDesc.Value
            return { Get: Getter, Set: Setter }

            Getter(Instance) {
                if (!(Instance is Private)) {
                    throw TypeError("Private property", -2, PropName)
                }
                return Value
            }
            Setter(Instance, NewValue) {
                if (!(Instance is Private)) {
                    throw TypeError("Private property", -2, PropName)
                }
                return (Value := NewValue)
            }
        }

        ; >>
        ; >>>>>>>> DEFINEPROP >>>>>>>>
        ; >>

        /**
         * Defines the `static DefineProp()` property to be used by the class.
         * 
         * @param   {Class}  Public   public class
         * @param   {Class}  Private  private class
         * @return  {Object}
         */
        static CreateStaticDefineProp(Public, Private) {
            return { Call: StaticDefineProp }

            StaticDefineProp(this, PropName, PropDesc) {
                ; MsgBox(this.Prototype.__Class)
                if (IsPrivate(PropName) && (this != Private)) {
                    throw Error("Private property", -2)
                }
                PropDesc := ConvertStaticProp(
                        PropName, PropDesc, Public, Private)
                return Define(this, PropName, PropDesc)
            }
        }

        /**
         * Defines the `DefineProp()` property to be used by the class.
         * 
         * @param   {Class}  Public   public class
         * @param   {Class}  Private  private class
         * @return  {Object}
         */
        static CreateDefineProp(Public, Private) {
            return { Call: DefineProp }

            DefineProp(this, PropName, PropDesc) {
                ; MsgBox(Type(this))
                if (IsPrivate(PropName) && !(this is Private)) {
                    throw Error("Private property", -2)
                }
                PropDesc := ConvertInstanceProp(
                        PropName, PropDesc,
                        this, Private)

                return Define(this, PropName, PropDesc)
            }
        }

        ; >>
        ; >>>>>>>> __SET >>>>>>>>
        ; >>

        /**
         * Defines the `static DefineProp()` property to be used by the class.
         * 
         * @param   {Class}  Public   public class
         * @param   {Class}  Private  private class
         * @return  {Object}
         */
        static StaticMetaSetter(Public, Private) {
            return { Call: static__Set }

            static__Set(Instance, PropName, Params, NewValue) {
                ; public properties are set from the base class directly
                if (!IsPrivate(PropName)) {
                    Define(Public, PropName, NewValue)
                    return
                }
                ; if the new property is private, validate that this method is
                ; called from the subclass, otherwise throw
                if (IsPrivate(PropName)) {
                    if (Instance != Private) {
                        throw Error("Private property")
                    }
                    Define(Private, PropName, { Value: NewValue })
                    return
                }
            }
        }

        /**
         * Defines the `DefineProp()` property to be used by the class.
         * 
         * @param   {Class}  Public   public class
         * @param   {Class}  Private  private class
         * @return  {Object}
         */
        static MetaSetter(Public, Private) {
            return { Call: __Set }

            __Set(this, PropName, Params, NewValue) {
                ; set public properties like normal
                if (!IsPrivate(PropName)) {
                    Define(this, PropName, NewValue)
                    return
                }
                ; validate if this private property has been set from inside the
                ; class, otherwise throw
                if (!(this is Private)) {
                    throw Error("Private property", -2)
                }
                ; define a property with type validation for the subclass
                Field := { Value: NewValue }
                PropDesc := PrivateField(PropName, Field, Public, Private)
                Define(this, PropName, PropDesc)
            }
        }
    }
}