#Requires AutoHotkey v2.0
#Include <AquaHotkeyX>

/**
 * 
 * 
 * @author 0w0Demonic
 */
class Alchemist
{
/**
 * Creates a new class based on the given `BaseClass`.
 * 
 * If the base class extends any other native class except for `Object`
 * or `Class`, this method fails below version v2.1-alpha.3.
 * 
 * @example
 * Test := Alchemist.CreateClass("Test")
 * 
 * MsgBox(Type(Test))     ; "Class"
 * MsgBox(Type(Test()))   ; "Test"
 * 
 * @param   {Class?}   BaseClass  base of the new class
 * @param   {String?}  Name       name of the new class
 * @return  {Class}
 */
static CreateClass(Name := "(unnamed)", BaseClass := Object) {
    if (!(BaseClass is Class)) {
        throw TypeError("Expected a Class",, Type(BaseClass))
    }
    if (IsObject(Name)) {
        throw TypeError("Expected a String",, Type(Name))
    }
    if (VerCompare(A_AhkVersion, "v2.1-alpha.3") >= 0) {
        Cls := Class(BaseClass)
    } else {
        Cls := Class()
        Cls.Prototype := Object()
        ObjSetBase(Cls, BaseClass)
        ObjSetBase(Cls.Prototype, BaseClass.Prototype)
    }
    Cls.Prototype.__Class := Name
    return Cls
}

/**
 * Creates a new class that is enclosed in the given object `Obj`.
 * 
 * @example
 * A := Alchemist.CreateClass("A")
 * B := Alchemist.CreateNestedClass(A, "B")
 * ; alternatively:
 * ; B := A.CreateNestedClass("B")
 * 
 * Obj := A.B()
 * MsgBox(Type(Obj)) ; "A.B"
 * 
 * @param   {Class}   Class         the enclosing class
 * @param   {String}  PropertyName  name of the assigned property
 * @param   {Class?}  BaseClass     base of the new class
 * @return  {Class}
 */
static CreateNestedClass(Obj, PropertyName, BaseClass := Object) {
    if (!(Obj is Class)) {
        throw TypeError("Expected a Class",, Type(Obj))
    }
    if (IsObject(PropertyName)) {
        throw TypeError("Expected a String",, Type(PropertyName))
    }
    Name := Obj.Prototype.__Class . "." . PropertyName
    Cls := Alchemist.CreateClass(Name, BaseClass)
    (Object.Prototype.DefineProp)(Obj, PropertyName, {
        Get: (_) => Cls,
        Call: (_, Args*) => Cls(Args*)
    })

    return Cls
}

/**
 * Modifies the class to support private fields.
 * Every field starting with one underscore (e.g. `_foo`) is seen as
 * private.
 * 
 * @example
 * class MyClass {
 *     _foo() => "bar"
 *     Foo() => this._Foo()
 * }
 * Alchemist.Privatize(MyClass)
 * 
 * MsgBox(MyClass.Foo()) ; "bar"
 * MsgBox(MyClass._foo()) ; [[ Error! ... has no method called "_foo". ]]
 * 
 * @description
 * Most of this works by:
 * - Creating a new class that extends the base class
 * - Moving private fields (beginning with one underscore) into the subclass
 * - Changing the base to the subclass on public properties to "elevate access"
 * 
 * Here's a simplified version of what's happening:
 * 
 * @example
 * ; before conversion
 * class A {
 *     Foo() => this._foo()
 *     _Foo() => MsgBox("private method!")
 * }
 * 
 * @example
 * ; after conversion
 * class A {
 *     Foo() {
 *         ObjSetBase(this, B.Prototype) ; "elevate access"
 *         try {
 *             Result := this._Foo()
 *         } catch as e {
 *         }
 *         ObjSetBase(this, A.Prototype) ; change back to regular base
 *         if (IsSet(e)) {
 *             throw e
 *         }
 *         return Result
 *     }
 * }
 * ; (unreachable generated class)
 * class B extends A {
 *     _Foo() {
 *         MsgBox("private method!")
 *     }
 * }
 * 
 * @param   {Class}  Cls  the class to be privatized
 * @return  {Class}
 */
static PrivatizeClass(Cls) {
    static Define := (Object.Prototype.DefineProp)
    static Delete := (Object.Prototype.DeleteProp)
    static GetProp := (Object.Prototype.GetOwnPropDesc)

    static Access := Map()

    BaseClass := Cls
    BaseClassName := BaseClass.Prototype.__Class
    Subclass := Alchemist.CreateClass(BaseClassName . "(internal)", BaseClass)

    Access.Set(BaseClass, Subclass)

    BaseClassProto := BaseClass.Prototype
    SubclassProto  := Subclass.Prototype

    __Set := CreateMetaSetter(BaseClassProto, SubclassProto)
    static__Set := CreateMetaSetter(BaseClass, Subclass)

    Define(BaseClass, "__Set", static__Set)
    Define(BaseClassProto, "__Set", __Set)

    __Init := CreateInitializer(BaseClassProto, SubclassProto)
    Define(BaseClassProto, "__Init", __Init)

    Define(BaseClassProto, "__Delete", { Call: Destructor })

    Transfer(BaseClass, Subclass,
            "Prototype", "__New")

    Transfer(BaseClassProto, SubclassProto,
            "__Set", "__New",
            "__Init", "__Delete")

    return Cls

    /**
     * `__Delete()` method that removes the weak reference from the `Access`
     * map.
     * 
     * @param   {Object}  Instance  object that called the destructor
     */
    static Destructor(Instance) {
        Access.Delete(ObjPtr(Instance))
    }

    /**
     * @return  {Closure}
     */
    static CreateInitializer(BaseClassProto, SubclassProto) {
        if (HasProp(BaseClassProto, "__Init") &&
                (BaseClassProto.__Init != Object.Prototype.__Init)) {
            Callback := BaseClassProto.__Init
            return { Call: __InitEx }
        }
        return { Call: __Init }

        __Init(Instance) {
            PrivateAccess := Object()
            ObjSetBase(PrivateAccess, SubclassProto)
            Access.Set(ObjPtr(Instance), PrivateAccess)
        }

        __InitEx(Instance) {
            PrivateAccess := Object()
            ObjSetBase(PrivateAccess, SubclassProto)
            Access.Set(ObjPtr(Instance), PrivateAccess)
            Callback(Instance)
        }
    }

    /**
     * 
     */
    static CreateMetaSetter(BaseClassProto, SubclassProto) {
        return { Call: __Set }

        __Set(Instance, PropertyName, Params, Value) {
            if (IsPrivateField(PropertyName)) {
                Field := CreatePrivateField(Value, SubclassProto)
                Define(Instance, PropertyName, Field)
            } else {
                Field := CreateField(Value)
                Define(Instance, PropertyName, Field)
            }
        }
    }

    /**
     * 
     */
    static CreatePrivateField(Value, Private) {
        return { Get: Getter, Set: Setter }

        Getter(Instance) {
            if (!HasBase(Instance, Private)) {
                throw MemberError("Private field")
            }
            return Value
        }
        Setter(Instance, NewValue) {
            if (!HasBase(Instance, Private)) {
                throw MemberError("Private field")
            }
            Value := NewValue
        }
    }

    static CreateField(Value) {
        return { Get: Getter, Set: Setter }

        Getter(Instance) {
            return Value
        }
        Setter(Instance, NewValue) {
            Value := NewValue
        }
    }

    /**
     * 
     */
    static Transfer(Public, Private, ExcludedProps*) {
        for PropertyName in GetProperties(Public, ExcludedProps*) {
            PropDesc := GetProp(Public, PropertyName)
            if (IsPrivateField(PropertyName)) {
                Delete(Public, PropertyName)
                Define(Private, PropertyName, PropDesc)
            } else {
                ConvertToElevatingPropDesc(PropDesc, Public, Private)
                Define(Public, PropertyName, PropDesc)
            }
        }
    }

    /**
     * 
     */
    static ConvertToElevatingPropDesc(PropDesc, Public, Private) {
        if (ObjHasOwnProp(PropDesc, "Get")) {
            PropDesc.Get := CreateImpersonation(PropDesc.Get, Public, Private)
        }
        if (ObjHasOwnProp(PropDesc, "Set")) {
            PropDesc.Set := CreateImpersonation(PropDesc.Set, Public, Private)
        }
        if (ObjHasOwnProp(PropDesc, "Call")) {
            PropDesc.Call := CreateImpersonation(PropDesc.Call, Public, Private)
        }
        return PropDesc
    }

    /**
     * 
     */
    static CreateImpersonation(Callback, Public, Private) {
        return Impersonated

        /**
         * 
         */
        Impersonated(Instance, Args*) {
            ObjSetBase(Instance, Private)
            try {
                Result := Callback(Instance, Args*)
            } catch as e {
                ; (empty)
            }
            ObjSetBase(Instance, Public)
            if (IsSet(e)) {
                throw e
            }
            return Result
        }
    }

    /**
     * Collects all property names of the given object, excluding the ones
     * specified in `ExcludedProps`.
     * 
     * @param   {Object}   Target         the object to retrieve properties from
     * @param   {String*}  ExcludedProps  properties to be excluded
     * @return  {Array<String>}
     */
    static GetProperties(Target, ExcludedProps*) {
        Props := Map()
        Props.CaseSense := false
        for PropertyName in ObjOwnProps(Target) {
            Props.Set(PropertyName, true)
        }
        for ExcludedProp in ExcludedProps {
            if (Props.Has(ExcludedProp)) {
                Props.Delete(ExcludedProp)
            }
        }
        return Props
    }

    /**
     * Determines whether the given property name is seen as private.
     * 
     * @param   {String}  PropertyName  any property name
     * @return  {Boolean}
     */
    static IsPrivateField(PropertyName) => (PropertyName ~= "^_[^_]")
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
            return Alchemist.CreateClass(ClassName?, this)
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

class Test {
    _foo := 12
    Foo := 23

    GetFoo() => this._foo
}
Alchemist.PrivatizeClass(Test)

Obj := Test()
MsgBox(Obj.Foo) ; 23
MsgBox(Obj.GetFoo()) ; 12
MsgBox(Obj._foo) ; Error! ... has no property named "_foo".



; Obj := Object()
; Obj.DefineProp("Test", PropertyDescriptor()
;         .Get.Constantly(34).With(Logging)
;         .Set.Throwing(TypeError))
