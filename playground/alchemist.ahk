#Requires AutoHotkey v2.0
#Include <AquaHotkeyX>

/**
 * 
 * 
 * @author 0w0Demonic
 */
class Alchemist
{
static CreateClass(BaseClass := Object, PropertyName := "(unnamed)") {
    if (!(BaseClass is Class)) {
        throw TypeError("Expected a Class",, Type(BaseClass))
    }
    if (IsObject(PropertyName)) {
        throw TypeError("Expected a String",, Type(PropertyName))
    }
    if (VerCompare(A_AhkVersion, "v2.1-alpha.3") >= 0) {
        Cls := Class(BaseClass)
    } else {
        Cls := Class()
        Cls.Prototype := Object()
        ObjSetBase(Cls, BaseClass)
        ObjSetBase(Cls.Prototype, BaseClass.Prototype)
    }
    Cls.Prototype.__Class := PropertyName
    return Cls
}

static CreateNestedClass(Obj, PropertyName, BaseClass := Object) {
    if (!(Obj is Class)) {
        throw TypeError("Expected a Class",, Type(Obj))
    }
    if (IsObject(PropertyName)) {
        throw TypeError("Expected a String",, Type(PropertyName))
    }
    Name := Obj.Prototype.__Class . "." . PropertyName
    Cls := Alchemist.CreateClass(BaseClass, Name)
    (Object.Prototype.DefineProp)(Obj, PropertyName, {
        Get: (_) => Cls,
        Call: (_, Args*) => Cls(Args*)
    })

    return Cls
}

static PrivatizeClass(Cls) {
    
}

/**
 * AquaHotkey package, which is applied if the library is present in the script.
 */
class AquaHotkey_Extensions
{
    static __New() {
        if (IsSet(AquaHotkey) && (AquaHotkey is Class))
                && (ObjHasOwnProp(AquaHotkey, "__New")) {
            (AquaHotkey.__New)(this)
        }
    }

    class Object {
        BaseChain {
            get {
                Result := Array()
                Obj := this
                while (Obj != Object.Prototype) {
                    Obj := ObjGetBase(Obj)
                    Result.Push(Obj)
                }
                return Result
            }
        }
    }

    class Class {
        CreateNestedClass(PropertyName, BaseClass?) {
            return Alchemist.CreateNestedClass(this, PropertyName, BaseClass?)
        }

        CreateSubclass(ClassName?) {
            return Alchemist.CreateClass(this, ClassName?)
        }

        Privatize() {

        }
    }
} ; class AquaHotkey_Extensions
} ; class Alchemist

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
     * 
     */
    static From(Obj, PropertyName) {
        PropDesc := (Object.Prototype.GetOwnPropDesc)(Obj, PropertyName)
        ObjSetBase(PropDesc, PropertyDescriptor.Prototype)
        return PropDesc
    }

    /**
     * 
     */
    static DeletedFrom(Obj, PropertyName) {
        PropDesc := (Object.Prototype.GetOwnPropDesc)(Obj, PropertyName)
        (Object.Prototype.DeleteProp)(Obj, PropertyName)
        ObjSetBase(PropDesc, PropertyDescriptor.Prototype)
        return PropDesc
    }

    /**
     * Selects
     */
    Get  => this._Select("Get")

    /**
     * 
     */
    Set  => this._Select("Set")

    /**
     * 
     */
    Call => this._Select("Call")

    /**
     * 
     */
    Get(Getter)  => this._Customize("Get", Getter)

    /**
     * 
     */
    Set(Setter)  => this._Customize("Set", Setter)

    /**
     * 
     */
    Call(Method) => this._Customize("Call", Method)

    /**
     * Defines this property descriptor for the given object and property name.
     * 
     * @param   {Object}  TargetObj     
     * @param   {String}  PropertyName  
     * @return  {this}
     */
    Define(TargetObj, PropertyName) {
        PropDesc := this.Clone()
        ObjSetBase(PropDesc, Object.Prototype)
        PropDesc.Target := unset
        (Object.Prototype.DefineProp)(TargetObj, PropertyName, PropDesc)
        return this
    }

    /**
     * 
     */
    _Select(PropertyName) {
        this.Target := PropertyName
        ObjSetBase(this, PropertyDescriptor.Select.Prototype)
        return this
    }

    /**
     * 
     */
    _Customize(PropertyName, Callback) {
        this.Target := PropertyName
        ObjSetBase(this, PropertyDescriptor.Customize.Prototype)
        return this
    }

    /**
     * 
     */
    class Select extends PropertyDescriptor {
        /**
         * 
         */
        Constantly(Value) {
            return this._AddValue(Constantly)

            Constantly(*) {
                return Value
            }
        }

        /**
         * 
         */
        Remove() {
            (Object.Prototype.DeleteProp)(this, this.Target)
            ObjSetBase(this, PropertyDescriptor.Prototype)
            return this
        }

        /**
         * 
         */
        Nop() {
            return this._AddValue(Nop)

            Nop(*) {
                return ""
            }
        }

        /**
         * 
         */
        Throwing(Err) {
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

        /**
         * 
         */
        _AddValue(f) {
            (Object.Prototype.DefineProp)(this, this.Target, { Value: f })
            ObjSetBase(this, PropertyDescriptor.Customize.Prototype)
            return this
        }
    }

    /**
     * 
     */
    class Customize extends PropertyDescriptor {
        /**
         * 
         */
        ByName(Name) {
            if (IsObject(Name)) {
                throw TypeError("Expected a String",, Type(Name))
            }
        }

        /**
         * 
         */
        With(Decoration) {
            Target := this.Target
            this.%Target% := Decoration(this.%Target%)
            return this
        }

        /**
         * 
         */
        ImpersonatedAs(Obj) {

        }
    }
}

Logging(Callback) {
    return Logged

    Logged(Args*) {
        MsgBox("doing something...")
        return Callback(Args*)
    }
}

Obj := Object()
Obj.DefineProp("Test", PropertyDescriptor()
        .Get.Constantly(34).With(Logging)
        .Set.Throwing(TypeError))

