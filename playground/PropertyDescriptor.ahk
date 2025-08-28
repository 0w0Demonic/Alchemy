#Requires AutoHotkey v2.0

/**
 * 
 * @example
 * 
 * PropertyDescriptor() ; create new property descriptor
 *     .Get.Constantly(42) ; create getter that always returns 42
 *     .Set.Nop() ; create setter that does nothing
 *     .Define(Obj, "Test") ; define property descriptor as `Obj.Test`
 */
class PropertyDescriptor {
    /**
     * Creates a new property descriptor based on an existing object property.
     * 
     * @param   {Object}  Obj           any object
     * @param   {String}  PropertyName  name of the property
     * @return  {PropertyDescriptor}
     */
    static From(Obj, PropertyName) {
        PropDesc := (Object.Prototype.GetOwnPropDesc)(Obj, PropertyName)
        ObjSetBase(PropDesc, PropertyDescriptor.Prototype)
        return PropDesc
    }

    /**
     * Creates a new property descriptor based on the deleted property of an
     * object.
     * 
     * @param   {Object}  Obj           any object
     * @param   {String}  PropertyName  name of the property
     * @return  {PropertyDescriptor}
     */
    static DeletedFrom(Obj, PropertyName) {
        PropDesc := (Object.Prototype.GetOwnPropDesc)(Obj, PropertyName)
        (Object.Prototype.DeleteProp)(Obj, PropertyName)
        ObjSetBase(PropDesc, PropertyDescriptor.Prototype)
        return PropDesc
    }

    /**
     * Specifies a get-function to be added to the property descriptor.
     * 
     * @return  {PropertyDescriptor.Add}
     */
    Get => this._Select("Get")

    /**
     * Specifies a set-function to be added to the property descriptor.
     * 
     * @return  {PropertyDescriptor.Add}
     */
    Set => this._Select("Set")

    /**
     * Specifies a call-function to be added to the property descriptor.
     * 
     * @return  {PropertyDescriptor.Add}
     */
    Call => this._Select("Call")

    /**
     * Specifies the given get-function to be added to the property descriptor.
     * 
     * @param   {Func}  Getter  called when value is retrieved
     * @return  {PropertyDescriptor.Customize}
     */
    Get(Getter)  => this._Customize("Get", Getter)

    /**
     * Specifies the given set-function to be added to the property descriptor.
     * 
     * @param   {Func}  Setter  called when property is assigned a value
     * @return  {PropertyDescriptor.Customize}
     */
    Set(Setter)  => this._Customize("Set", Setter)

    /**
     * Specifies the given call-function to be added to the property descriptor.
     * 
     * @param   {Func}  Method  function called when property is being called
     * @return  {PropertyDescriptor.Customize}
     */
    Call(Method) => this._Customize("Call", Method)

    /**
     * Defines this property descriptor for the given object and property name.
     * 
     * @param   {Object}  TargetObj     the target object
     * @param   {String}  PropertyName  
     * @return  {this}
     */
    Define(TargetObj, PropertyName) {
        this._Validate()
        PropDesc := this.Clone()
        ObjSetBase(PropDesc, Object.Prototype)
        PropDesc.Target := unset
        (Object.Prototype.DefineProp)(TargetObj, PropertyName, PropDesc)
        return this
    }

    _Select(PropertyName) {
        this._Validate()
        this.Target := PropertyName
        ObjSetBase(this, PropertyDescriptor.Add.Prototype)
        return this
    }

    _Customize(PropertyName, Callback) {
        this.Target := PropertyName
        ObjSetBase(this, PropertyDescriptor.Customize.Prototype)
        return this
    }

    _Validate() {
        if (this is PropertyDescriptor.Add) {
            Extra := "Property '" . this.Target . "' unset"
            throw Error("Invalid syntax", -3, Extra)
        }
    }

    /**
     * Represents the 
     */
    class Add extends PropertyDescriptor {
        /**
         * Assigns a function that constantly returns `Value`.
         * 
         * @param   {Any}  Value  any value
         * @return  {PropertyDescriptor.Customize}
         */
        Constantly(Value) {
            return this._AddValue(Constantly)

            Constantly(*) => Value
        }

        /**
         * Removes the targeted function.
         * 
         * @return
         */
        Remove() {
            (Object.Prototype.DeleteProp)(this, this.Target)
            ObjSetBase(this, PropertyDescriptor.Prototype)
            return this
        }

        /**
         * Assigns a function that does nothing.
         * 
         * @return  {PropertyDescriptor.Customize}
         */
        Nop() {
            return this._AddValue(Nop)

            static Nop(*) {
                return ""
            }
        }

        /**
         * Assigns a function that throws an error when called.
         * 
         * @param   {Class?/Func?}  Err  error class or function supplier
         * @return  {PropertyDescriptor.Customize}
         */
        Throwing(Err := Error) {
            if (Err is Func) {
                return this._AddValue(Throwing)
            }
            if (!(Err is Class)) {
                throw TypeError("Expected an Error class or Func",, Type(Err))
            }
            if (!(Err == Error) && !HasBase(Err, Error)) {
                throw ValueError("Not an Error class",, Err.Prototype.__Class)
            }
            return this._AddValue(Throwing)

            Throwing(*) {
                throw Err()
            }
        }

        _AddValue(f) {
            (Object.Prototype.DefineProp)(this, this.Target, { Value: f })
            ObjSetBase(this, PropertyDescriptor.Customize.Prototype)
            return this
        }
    }

    class Customize extends PropertyDescriptor {
        /**
         * Assigns the given name to the function.
         * 
         * @param   {String}  Name  name of the function
         * @return  {this}
         */
        ByName(Name) {
            if (IsObject(Name)) {
                throw TypeError("Expected a String",, Type(Name))
            }

            f := this.%(this.Target)%
            (Object.Prototype.DefineProp)(f, "Name", (*) => Name)
            return this
        }

        /**
         * Decorates the given function.
         * 
         * @param   {Func}  Decorator  the given decorator
         * @return  {this}
         */
        With(Decorator) {
            GetMethod(Decorator)
            Target := this.Target
            this.%Target% := Decorator(this.%Target%)
            return this
        }

        /**
         * Changes the function to act as if called by `Obj`.
         * 
         * @param   {Object}  Obj  object to impersonate as
         * @return  {this}
         */
        ImpersonatedAs(Obj) {
            if (!IsObject(Obj)) {
                throw TypeError("Expected an Object",, Type(Obj))
            }
            f := this.%this.Target%
            this.%(this.Target)% := (Instance, Args*) => f(Obj, Args*)
            return this
        }
    }
}

