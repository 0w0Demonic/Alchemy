#Requires AutoHotkey v2.0

class Privatizer {
    static Transform(Target) {
        ; `.DefineProp()`, paranoia edition
        static Define  := (Object.Prototype.DefineProp)
        static Delete  := (Object.Prototype.DeleteProp)
        static GetProp := (Object.Prototype.GetOwnPropDesc)

        ; all descriptors for dynamic properties
        static Descriptors := Array("Get", "Set", "Call")

        ; some debug output (absolutely life-saving for something like this)
        static Debug(FormatString, Args*) {
            OutputDebug(Format("[DEBUG] " . FormatString . "`r`n", Args*))
        }

        if (!(Target is Class)) {
            throw TypeError("Expected a Class",, Type(Target))
        }

        BaseClass := Target
        BaseProto := BaseClass.Prototype
        BaseClassName := BaseProto.__Class
        SubclassName := BaseClassName . "(private)"

        Debug("######## Privatizing class: '{1}' ########", BaseProto.__Class)
        Debug("")
        Debug("creating subclass:")
        Debug("    {1} extends {2} {{} ... {}}", SubclassName, BaseClassName)
        Subclass  := CreateSubclass(BaseClass, SubclassName)
        SubProto  := Subclass.Prototype
        Debug("done.")
        Debug("")
        Debug("defining '{1}.__Set()'", BaseClassName)
        Define(BaseClass, "__Set", StaticMetaSetter(BaseClass, Subclass))
        Debug("defining '{1}.Prototype.__Set()'", BaseClassName)
        Define(BaseProto, "__Set", MetaSetter(BaseClass, Subclass))
        Debug("done.")
        Debug("")
        Debug("modifying static properties ({1}):", BaseClassName)
        for PropertyName, PropDesc in FindProps(BaseClass, "__Set") {
            ConvertStaticProp(PropertyName, PropDesc)
        }
        Debug("done.")
        Debug("")
        Debug("modifying instance properties ({1}.Prototype):", BaseClassName)
        for PropertyName, PropDesc in FindProps(BaseProto, "__Set") {
            ConvertInstanceProp(PropertyName, PropDesc)
        }
        Debug("done.")
        Debug("")
        Debug("----------------------------------------------")
        return

; >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

        /**
         * Converts regular static properties of the class into ones that
         * support the use of private fields.
         * 
         * @param   {String}  PropertyName  name of the property
         * @param   {Object}  PropDesc      property descriptor object
         */
        ConvertStaticProp(PropertyName, PropDesc) {
            if (IsPrivate(PropertyName)) {
                ; move private static to the subclass
                Debug("    {1:-20} : {2}", "private", PropertyName)
                Delete(BaseClass, PropertyName)
                Define(Subclass, PropertyName, PropDesc)
            } else {
                ; decorate public static properties with impersonation as
                ; subclass
                Debug("    {1:-20} : {2}", "public", PropertyName)
                Define(BaseClass, PropertyName,
                        PublicStaticProp(PropDesc, BaseClass, Subclass))
            }
        }

        /**
         * Converts regular instance properties of the class into ones that
         * support the use of private fields.
         * 
         * @param   {String}  PropertyName  name of the property
         * @param   {Object}  PropDesc      property descriptor object
         */
        ConvertInstanceProp(PropertyName, PropDesc) {
            switch {
                ; decorate public instance properties with
                ; "temporary elevation" to the subclass, enabling full access
                ; to properties
                case (!IsPrivate(PropertyName)):
                    Debug("    {1:-20} : {2}", "public", PropertyName)
                    Define(BaseProto, PropertyName,
                            PublicProp(PropDesc, BaseProto, SubProto))

                ; validate private fields to ensure they've been accessed from
                ; the elevated subclass
                case (IsField(PropDesc)):
                    Debug("    {1:-20} : {2}", "private field", PropertyName)
                    Define(BaseProto, PropertyName,
                            PrivateField(PropDesc.Value, SubProto))
                
                ; move everything else into the subclass
                default:
                    Debug("    {1:-20} : {2}", "private property", PropertyName)
                    Delete(BaseProto, PropertyName)
                    Define(SubProto, PropertyName, PropDesc)
            }
        }

        /**
         * Creates a subclass of the given `BaseClass`
         * 
         * @param   {Class}   BaseClass  base class to be derived from
         * @param   {String}  Name       name of the class
         * @return  {Class}
         */
        static CreateSubclass(BaseClass, Name) {
            if (VerCompare(A_AhkVersion, "2.1-alpha.3") >= 0) {
                ; TODO probably try to remove all custom `static __New()`'s
                ; temporarily so you don't cause infinite recursion
                Subclass := Class(BaseClass)
            } else {
                Subclass := Class()
                Subclass.Prototype := Object()
                ObjSetBase(Subclass, BaseClass)
                ObjSetBase(Subclass.Prototype, BaseClass.Prototype)
            }
            Subclass.Prototype.__Class := Name
            return Subclass
        }

        /**
         * Iterates through properties of any given object, returning a map
         * of property names mapped to their property descriptor
         * 
         * @param   {Object}   Target         any object
         * @param   {String*}  ExcludedProps  properties to be ignored
         * @return  {Map}
         */
        static FindProps(Target, ExcludedProps*) {
            static GetProp := (Object.Prototype.GetOwnPropDesc)
            M := Map()
            M.CaseSense := false
            for PropertyName in ObjOwnProps(Target) {
                M.Set(PropertyName, GetProp(Target, PropertyName))
            }
            for ExcludedProp in ExcludedProps {
                if (M.Has(ExcludedProp)) {
                    M.Delete(ExcludedProp)
                }
            }
            return M
        }

        /**
         * Determines whether the given property descriptor defines a regular
         * field.
         * 
         * @param  {Object}  PropDesc  the property descriptor to be checked
         */
        static IsField(PropDesc) => ObjHasOwnProp(PropDesc, "Value")

        /**
         * Decorates a property descriptor with impersonation as the hidden
         * subclass
         * 
         * @param   {Object}  PropDesc  property descriptor to be wrapped around
         * @param   {Class}   Public    public class
         * @param   {Class}   Private   internal subclass
         * @return  {Object}
         */
        static PublicStaticProp(PropDesc, Public, Private) {
            return DecorateProp(PropDesc, Impersonation)

            Impersonation(Callback) {
                return Impersonated

                Impersonated(_, Args*) {
                    return Callback(Private, Args*)
                }
            }
        }

        /**
         * Decorates a property descriptor with "temporary elevation" in which
         * the calling object's base is being set to the subclass for granting
         * access to private properties.
         * 
         * @param   {Object}  PropDesc  property descriptor to be wrapped around
         * @param   {Object}  Public    public class prototype
         * @param   {Object}  Private   internal subclass prototype
         * @return  {Object}
         */
        static PublicProp(PropDesc, Public, Private) {
            return DecorateProp(PropDesc, Elevation)

            Elevation(Callback) {
                return Elevated

                Elevated(Instance, Args*) {
                    ObjSetBase(Instance, Private)
                    try {
                        Result := Callback(Instance, Args*)
                        ObjSetBase(Instance, Public)
                        return Result
                    } catch as Ex {
                        ObjSetBase(Instance, Public)
                        throw Ex
                    }
                }
            }
        }

        /**
         * Decorates a property descriptor by applying the specified
         * `Decorator`. Regular fields (i.e. with `Value`) are left unchanged.
         * 
         * @param   {Object}  PropDesc   property descriptor to wrap around
         * @param   {Func}    Decorator  decorator to be used
         * @return  {Object}
         */
        static DecorateProp(PropDesc, Decorator) {
            if (IsField(PropDesc)) {
                return PropDesc
            }
            Result := Object()
            for Descriptor in Descriptors {
                if (ObjHasOwnProp(PropDesc, Descriptor)) {
                    ; absolute paranoia
                    Define(Result, Descriptor, {
                        Value: Decorator(GetProp(PropDesc, Descriptor).Value)
                    })
                }
            }
            return Result
        }

        /**
         * Defines the `static __Set()` meta-property for privatized classes.
         * 
         * @param   {Class}  Public   base class
         * @param   {Class}  Private  hidden subclass
         * @return  {Object}
         */
        static StaticMetaSetter(Public, Private) {
            return { Call: static__Set }

            static__Set(Instance, PropertyName, Params, NewValue) {
                ; public properties are set from the base class directly
                if (!IsPrivate(PropertyName)) {
                    Define(Public, PropertyName, NewValue)
                    return
                }
                ; if the new property is private, validate that this method is
                ; called from the subclass, otherwise throw
                if (IsPrivate(PropertyName)) {
                    if (Instance != Private) {
                        throw Error("Private property")
                    }
                    Define(Private, PropertyName, NewValue)
                    return
                }
            }
        }

        /**
         * Defines the `__Set()` meta-property for privatized classes.
         * 
         * @param   {Class}  Public   base class
         * @param   {Class}  Private  hidden subclass
         * @return  {Object}
         */
        static MetaSetter(Public, Private) {
            return { Call: __Set }

            __Set(Instance, PropertyName, Params, NewValue) {
                ; set public properties like normal
                if (!IsPrivate(PropertyName)) {
                    Define(Instance, PropertyName, NewValue)
                    return
                }
                ; validate if this private property has been set from inside the
                ; class, otherwise throw
                if (!(Instance is Private)) {
                    throw Error("Private property", -2)
                }
                ; define a property with type validation for the subclass
                Define(Instance, PropertyName, PrivateField(NewValue, Private))
            }
        }

        /**
         * Creates a property that simulates a regular field, but with
         * additional type checking to validate access to the field.
         * 
         * @param   {Any}    Value    value of the field
         * @param   {Class}  Private  hidden subclass
         * @return  {Object}
         */
        static PrivateField(Value, Private) {
            return { Get: Getter, Set: Setter }

            Getter(Instance) {
                if (!(Instance is Private)) {
                    throw TypeError("Private property", -2)
                }
                return Value
            }
            Setter(Instance, NewValue) {
                if (!(Instance is Private)) {
                    throw TypeError("Private property", -2)
                }
                return (Value := NewValue)
            }
        }

        /**
         * Determines whether a property is public or private.
         * 
         * @param   {String}  PropertyName  name of the property
         * @return  {Boolean}
         */
        static IsPrivate(PropertyName) => (PropertyName ~= "^_[^_]")
    }
}



class Foo {
    a => "public"
    _a => "private"

    SetFoo(Value) {
        this._foo := Value
    }
    GetFoo() {
        return this._foo
    }
}

Privatizer.Transform(Foo)

Obj := Foo()
Obj.SetFoo(21)
MsgBox(Obj.GetFoo())
MsgBox(Obj._foo)