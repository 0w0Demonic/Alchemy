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
    static Debug(FormatString, Args*) {
        OutputDebug(Format("[Alchemist] " . FormatString . "`r`n", Args*))
    }

    ; paranoia
    if (!(Cls is Class)) {
        throw TypeError("Expected a Class",, Type(Cls))
    }
    ; even more paranoia
    if (!ObjHasOwnProp(Cls, "Prototype")) {
        throw UnsetError("Class has no prototype of its own")
    }


    BaseClass := Cls
    BaseClassName := BaseClass.Prototype.__Class

    Debug("######## Privatizing class: '{1}' ########", BaseClassName)

    SubclassName := BaseClassName . "(internal)"
    Debug("creating subclass:")
    Debug("    {1} extends {2} {{} ... {}}", SubclassName, BaseClassName)
    Debug("done.")
    
    ; create a new subclass to move all "private fields" into
    Subclass := Alchemist.CreateClass(SubclassName, BaseClass)

    BaseClassProto := BaseClass.Prototype
    SubclassProto  := Subclass.Prototype

    ; define `static __Set()`
    Debug("defining '{1}.__Set()'", BaseClassName)
    Define(BaseClass, "__Set", MetaSetter(Subclass))

    ; define `__Set()`
    Debug("defining '{1}.Prototype.__Set()'", BaseClassName)
    Define(BaseClassProto, "__Set", MetaSetter(SubclassProto))

    ; transform existing properties of the class
    Debug("modifying static properties ({1}):", BaseClassName)
    Transfer(BaseClass, Subclass, "Prototype", "__Set")
    Debug("done.")

    Debug("modifying instance properties ({1}.Prototype):", BaseClassName)
    Transfer(BaseClassProto, SubclassProto, "__Set")
    Debug("done.")
    Debug("----------------------------------------------")
    return Cls


    /**
     * Converts all existing properties in the class/prototype to support
     * private fields. This is done by moving private fields from `Public` into
     * the deriving `Private`.
     * 
     * @param   {Object}   Public         base object (public access)
     * @param   {Object}   Private        deriving object (private access)
     * @param   {String*}  ExcludedProps  list of properties to be ignored
     */
    static Transfer(Public, Private, ExcludedProps*) {
        for PropertyName in GetProperties(Public, ExcludedProps*) {
            PropDesc := GetProp(Public, PropertyName)
            if (IsPrivateField(PropertyName)) {
                Debug("    private : '{1}'", PropertyName)
                Delete(Public, PropertyName)
                Define(Private, PropertyName, PropDesc)
            } else {
                Debug("    public  : '{1}'", PropertyName)
                ConvertToElevatingPropDesc(PropDesc, Public, Private)
                Define(Public, PropertyName, PropDesc)
            }
        }
    }

    /**
     * Collects all property names of the given object, excluding the ones
     * specified in `ExcludedProps`. This is done to avoid modifying properties
     * during an `ObjOwnProps()`-loop.
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
     * Converts properties seen as public to "elevate access" before calling
     * their original implementation.
     * 
     * @param   {Object}  PropDesc  property descriptor to be converted
     * @param   {Object}  Public    base object (public access)
     * @param   {Object}  Private   deriving object (private access)
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
     * Creates a closure that "elevates access" to the deriving object before
     * calling the given `Callback`.
     * 
     * @param   {Func}    Callback  the function to be called
     * @param   {Object}  Public    base object (public access)
     * @param   {Object}  Private   deriving object (private access)
     */
    static CreateImpersonation(Callback, Public, Private) {
        if ((Public is Class) && (Private is Class)) {
            return ImpersonatedClass
        }
        return ImpersonatedInstance

        ImpersonatedClass(Instance, Args*) {
            return Callback(Private, Args*)
        }

        ImpersonatedInstance(Instance, Args*) {
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
     * Defines new `__Set` and `static __Set` for the given class.
     * Whenever the class or an instance declares a new field, a new
     * field is created whose "access permission" can be validated.
     * 
     * @param   {Object}  Private  hidden 
     */
    static MetaSetter(Private) {
        if (Private is Class) {
            return { Call: static__Set }
        }
        return { Call: __Set }

        /**
         * Method that is called, when the instance declares a new field.
         * A new "pseudo-field" is created (i.e.: a regular property with `Get`
         * and `Set` with equivalent behavior). Depending on the property name,
         * the type of the object is validated to ensure it has
         * "elevated access", otherwise an error is thrown.
         * 
         * @param   {Object}  Instance      instance that declares the property
         * @param   {String}  PropertyName  name of the property
         * @param   {Array}   Params        params in square brackets (ignored)
         * @param   {Any}     Value         the value that was assigned
         */
        __Set(Instance, PropertyName, Params, Value) {
            ; TODO add validation so that the object can only set new fields
            ;      with elevated access?
            if (IsPrivateField(PropertyName)) {
                ; create field with validation
                Field := CreateField(Value, Private)
            } else {
                ; create field without validation
                Field := CreateField(Value)
            }
            ; define new field
            Define(Instance, PropertyName, Field)
        }

        /**
         * This method is called when a new field is assigned from the class
         * itself. There's no need to do any tricky validation, just assign
         * the field to the hidden subclass depending on the name.
         * 
         * @param   {Class}   Instance      class that declares the property
         * @param   {String}  PropertyName  name of the property
         * @param   {Array}   Params        params in square brackets (ignored)
         * @param   {Any}     Value         the value that was assigned
         */
        static__Set(Instance, PropertyName, Params, Value) {
            ; Property descriptor for a regular field
            Field := { Value: Value }
            ; If the property is private, assign it to the subclass. Otherwise,
            ; assign to the current class.
            Define(IsPrivateField(PropertyName) ? Private : Instance,
                    PropertyName, Field)
        }
    }

    /**
     * Creates a "pseudo-field", i.e. a dynamic property with `Get` and `Set`,
     * that can optionally be validated for access.
     * 
     * @param   {Any}      Value    any value
     * @param   {Object?}  Private  reference to the subclass's prototype
     * @return  {Object}
     */
    static CreateField(Value, Private?) {
        if (IsSet(Private)) {
            return { Get: PrivateGetter, Set: PrivateSetter }
        } else {
            return { Get: Getter, Set: Setter }
        }

        Getter(Instance) {
            return Value
        }
        Setter(Instance, NewValue) {
            Value := NewValue
        }

        PrivateGetter(Instance) {
            if (!HasBase(Instance, Private)) {
                throw MemberError("Private field")
            }
            return Value
        }

        PrivateSetter(Instance, NewValue) {
            if (!HasBase(Instance, Private)) {
                throw MemberError("Private field")
            }
            Value := NewValue
        }
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
 * AquaHotkey-style extensions, applied if the library is available.
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
            Alchemist.CreateClass(ClassName?, this)
        }

        Privatize() => Alchemist.PrivatizeClass(this)
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

; class Test {
;     static _foo := 12
;     static Foo := 23
; 
;     static GetFoo() => this._foo
;     static GetBar() => this._bar
; }
; Alchemist.PrivatizeClass(Test)

; Obj := Object()
; Obj.DefineProp("Test", PropertyDescriptor()
;         .Get.Constantly(34).With(Logging)
;         .Set.Throwing(TypeError))
