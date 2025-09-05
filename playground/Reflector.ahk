#Requires AutoHotkey v2.0

class Reflector {
    static FindProps(Target, Condition := AcceptAll, Mapper := Self) {
        static AcceptAll(*) => true
        static Self(x) => x

        if (!IsObject(Target)) {
            throw TypeError("Expected an Object",, Type(Target))
        }
        GetMethod(Condition)
        GetMethod(Mapper)

        Props := Reflector.Properties()
        for PropertyName in ObjOwnProps(Target) {
            PropDesc := (Object.Prototype.GetOwnPropDesc)(Target, PropertyName)
            if (Condition(PropertyName, PropDesc)) {
                Props.Set(PropertyName, Mapper(PropDesc))
            }
        }
        return Props
    }

    class Properties extends Map {
        CaseSense := false

        Without(ExcludedProps*) {
            for ExcludedProp in ExcludedProps {
                if (this.Has(ExcludedProp)) {
                    this.Remove(ExcludedProp)
                }
            }
            return this
        }
    }
}

class Enum {
    static GetConstants(Target) {
        return Reflector.FindProps(Target, IsConstantGetter, GetValue)

        static IsConstantGetter(PropertyName, PropDesc) {
            if (ObjOwnPropCount(PropDesc) != 1
                || !ObjHasOwnProp(PropDesc, "Get"))
            {
                return false
            }
            return ()
                && (ObjHasOwnProp(PropDesc, "Get"))
        }

        GetValue(PropDesc) {
            return (PropDesc.Get)(Target)
        }
    }
}