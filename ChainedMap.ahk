#Requires AutoHotkey v2

/**
 * A map with prototype-style inheritance.
 * 
 * Each `ChainedMap` can optionally link to a "parent" map. When a key lookup
 * fails in the current map, it automatically falls back to its parent map,
 * continuing up the chain util the key is found.
 * 
 * Perfect for...
 * - layered configs
 * - context-sensitive overrides
 * - tree-like structures for theme settings, localization, etc.
 * 
 * Maps are required to have the same values for their `Default` and `CaseSense`
 * properties, which are automatically set based on the parent map.
 * 
 * The parent from which the map inherits is referred to by the `.Next`
 * property. It is automatically assigned, when a new chained map is created,
 * and read-only.
 */
class ChainedMap extends Map {
    /**
     * Returns a new chained map with the given parent map to inherit from.
     * 
     * You should generally use `ChainedMap.Base()`, `ChainedMap.Extend()`, or
     * `.Extend()` instead.
     * 
     * @example
     * A := ChainedMap(unset, "foo", "bar")
     * B := ChainedMap(A)
     * 
     * B["foo"] ; "bar"
     * 
     * @param   {Map?}  Next  base map to inherit from
     * @param   {Any*}  Args  key-value pairs to add
     * @return  {ChainedMap}
     */
    __New(Next?, Args*) {
        if (!IsSet(Next)) {
            super.__New(Args*)
            return
        }
        if (!(Next is Map)) {
            throw TypeError("Expected a Map",, Type(Next))
        }
        this.CaseSense := Next.CaseSense
        if (ObjHasOwnProp(Next, "Default")) {
            (Map.Prototype.Default.Set)(this, Next.Default)
        }
        super.__New(Args*)
        (Object.Prototype.DefineProp)(this, "Next", { Get: (_) => Next })
    }

    /**
     * Returns a new chained map with no parent map to inherit from.
     * 
     * @example
     * A := ChainedMap.Base("foo", "bar")
     * B := A.Extend("foo", "baz")
     * 
     * @param   {Any*}  Args  key-value pairs to add
     * @return  {ChainedMap}
     */
    static Base(Args*) {
        return ChainedMap(unset, Args*)
    }

    /**
     * Returns a new chained map that inherits from the given `BaseMap`.
     * 
     * @example
     * A := ChainedMap.Base("foo", "bar")
     * B := ChainedMap.Extend(A, "foo", "baz")
     * 
     * @param   {Map}   BaseMap  base map to inherit from
     * @param   {Any*}  Args     key-value pairs to add
     * @return  {ChainedMap}
     */
    static Extend(BaseMap, Args*) {
        return ChainedMap(BaseMap, Args*)
    }

    /**
     * Clears all key-value pairs from the current, and all of its parent maps.
     * 
     * @example
     * A := ChainedMap.Base("foo", "bar")
     * B := A.Extend()
     * B.Clear()
     * B.Has("foo") ; false
     */
    Clear() {
        MapObj := this
        Loop {
            (Map.Prototype.Clear)(MapObj)
            if (!ObjHasOwnProp(MapObj, "Next")) {
                return
            }
            MapObj := MapObj.Next
        }
    }

    /**
     * Clears all key-value pairs from the map, without clearing its parent
     * maps.
     * 
     * @example
     * A := ChainedMap.Base("foo", "bar")
     * B := A.Extend("foo", "baz", "hello", "world")
     * B.ClearOwn()
     * B["foo"]       ; "bar"
     * B.Has("hello") ; false
     */
    ClearOwn() {
        (Map.Prototype.Clear)(this)
    }

    /**
     * Performs a deep clone of the current map down its chain of parents.
     * 
     * @example
     * A := ChainedMap.Base("foo", "bar")
     * B := A.Extend("baz", "qux")
     * 
     * Cloned := B.Clone()
     * MsgBox(Cloned.Next == A) ; false
     */
    Clone() {
        Result := (Map.Prototype.Clone)(this)
        MapObj := Result
        Loop {
            if (!ObjHasOwnProp(MapObj, "Next")) {
                break
            }
            Cloned := (Map.Prototype.Clone)(MapObj.Next)
            (Object.Prototype.DefineProp)(MapObj, "Next", CreateGetter(Cloned))
            MapObj := MapObj.Next
        }
        return Result

        static CreateGetter(Value) => { Get: (_) => Value }
    }

    /**
     * Performs a shallow clone of the current map.
     * 
     * @example
     * A := ChainedMap.Base("foo", "bar")
     * B := A.Extend("baz", "qux")
     * 
     * Cloned := B.Clone()
     * MsgBox(B.Next == A) ; true
     */
    CloneOwn() {
        return (Map.Prototype.Clone)(this)
    }

    /**
     * Removes a key-value pair from the current map, falling back to parent
     * maps if absent. Only the first found key-value pair is deleted.
     * 
     * @example
     * A := ChainedMap.Base("foo", "bar")
     * B := A.Extend("baz", "qux")
     * 
     * B.Delete("foo")
     * B.Has("foo") ; false
     * 
     * @param   {Any}  Key  the key to delete
     * @return  {Any}
     */
    Delete(Key) {
        MapObj := this
        Loop {
            if ((Map.Prototype.Has)(this, Key)) {
                break
            }
            if (!ObjHasOwnProp(this, "Next")) {
                throw UnsetItemError("Key not found")
            }
            MapObj := MapObj.Next
        }
        return (Map.Prototype.Delete)(this, Key)
    }

    /**
     * Removes a key-value pair from the current map, without falling back
     * to parent maps.
     * 
     * @example
     * A := ChainedMap.Base("foo", "bar")
     * B := A.Extend("foo", "baz")
     * B.DeleteOwn("foo")
     * B["foo"] ; "bar"
     * 
     * @param   {Any}  Key  the key to delete
     * @return  {Any}
     */
    DeleteOwn(Key) {
        return (Map.Prototype.Delete)(this, Key)
    }

    /**
     * Removes a key-value pair from the map, and all of its parents.
     * An array of all deleted values is returned.
     * 
     * @example
     * A := ChainedMap.Base("foo", "bar")
     * B := A.Extend("foo", "baz")
     * 
     * Result := B.DeleteAll("foo") ; ["baz", "bar"]
     * 
     * A.HasOwn("foo") ; false
     * B.HasOwn("foo") ; false
     * B.Count      ; 0
     * 
     * @param   {Any}  Key  the key to delete
     * @return  {Array}
     */
    DeleteAll(Key) {
        MapObj := this
        Result := Array()
        Loop {
            if ((Map.Prototype.Has)(MapObj, Key)) {
                Value := (Map.Prototype.Delete)(MapObj, Key)
                Result.Push(Value)
            }
            if (!ObjHasOwnProp(MapObj, "Next")) {
                return
            }
            MapObj := MapObj.Next
        }
        return Result
    }

    /**
     * Returns a value from the chained map, falling back to parent maps if
     * needed.
     * 
     * @example
     * A := ChainedMap.Base("foo", "bar")
     * B := A.Extend()
     * 
     * B.Get("foo") ; "bar"
     * 
     * @param   {Any}   Key      the map key to retrieve value from
     * @param   {Any?}  Default  default value to return
     * @return  {Any}
     */
    Get(Key, Default?) {
        MapObj := this
        Loop {
            if ((Map.Prototype.Has)(MapObj, Key)) {
                return (Map.Prototype.Get)(MapObj, Key)
            }
            if (!ObjHasOwnProp(MapObj, "Next")) {
                if (IsSet(Default)) {
                    return Default
                }
                throw UnsetItemError("Key not found")
            }
            MapObj := MapObj.Next
        }
    }

    /**
     * Returns a value from the chained map, without falling back to parent
     * maps.
     * 
     * @example
     * A := ChainedMap.Base("foo", "bar")
     * B := A.Extend()
     * 
     * B.GetOwn("foo") ; Error!
     * 
     * @param   {Any}   Key      the map key to retrieve value from
     * @param   {Any?}  Default  default value to return
     * @return  {Any}
     */
    GetOwn(Key, Default?) {
        return (Map.Prototype.Get)(this, Key, Default?)
    }

    /**
     * Returns all values by the given key in the form of an array. If no value
     * can be found, this method returns an empty array.
     * 
     * @example
     * A := ChainedMap.Base("foo", "bar")
     * B := A.Extend("foo", "baz")
     * 
     * B.GetAll("foo") ; ["baz", "bar"]
     * 
     * @param   {Any}  Key  the map key to retrieve values from
     * @return  {Array}
     */
    GetAll(Key) {
        Result := Array()
        MapObj := this

        Loop {
            if ((Map.Prototype.Has)(MapObj, Key)) {
                Result.Push((Map.Prototype.Get)(MapObj, Key))
            }
            if (!ObjHasOwnProp(MapObj, "Next")) {
                break
            }
            MapObj := MapObj.Next
        }
        return Result
    }

    /**
     * Returns `true` if the specified `Key` is present in the map, falling
     * back to parent maps when needed.
     * 
     * @example
     * A := ChainedMap.Base("foo", "bar")
     * B := A.Extend()
     * 
     * B.Has("foo") ; true
     * 
     * @param   {Any}  Key  any map key
     * @return  {Boolean}
     */
    Has(Key) {
        MapObj := this
        Loop {
            if ((Map.Prototype.Has)(MapObj, Key)) {
                return true
            }
            if (!ObjHasOwnProp(MapObj, "Next")) {
                return false
            }
            MapObj := MapObj.Next
        }
    }

    /**
     * Returns `true` if the specified `Key` is present in the current map,
     * without falling back to parent maps.
     * 
     * @example
     * A := ChainedMap.Base("foo", "bar")
     * B := A.Extend()
     * 
     * B.Has("foo")    ; true
     * B.HasOwn("foo") ; false
     * 
     * @param   {Any}  Key  any map key
     * @return  {Boolean}
     */
    HasOwn(Key) {
        return (Map.Prototype.Has)(this, Key)
    }

    /**
     * Returns the number of key-value pairs present in the map, without
     * counting key-value pairs from parent maps.
     * 
     * @example
     * A := ChainedMap.Base("foo", "bar")
     * B := A.Extend()
     * 
     * B.OwnCount ; 0
     * 
     * @return  {Integer}
     */
    OwnCount {
        get {
            static Prop  := (Object.Prototype.GetOwnPropDesc)
            static Count := Prop(Map.Prototype, "Count").Get

            return Count(this)
        }
    }

    /**
     * Returns the number of *unique* key-value pairs from the current map,
     * down the chain of parent maps.
     * 
     * @example
     * A := ChainedMap(unset, "foo", "bar")
     * B := A.Extend("baz", "qux", "foo", "baz") ; "foo" overridden
     * 
     * B.Count    ; 2
     * 
     * @return  {Integer}
     */
    Count {
        get {
            MapObj := this
            Seen := Map()
            Seen.CaseSense := this.CaseSense

            Loop {
                for Key, Value in (Map.Prototype.__Enum)(MapObj) {
                    Seen.Set(Key, Value)
                }
                if (!ObjHasOwnProp(MapObj, "Next")) {
                    break
                }
                MapObj := MapObj.Next
            }
            return Seen.Count
        }
    }

    /**
     * Returns the sum of all key-value pairs from the current map, down the
     * chain of parent maps.
     * 
     * @example
     * A := ChainedMap.Base("foo", "bar")
     * B := A.Extend("baz", "qux", "foo", "baz") ; "foo" overridden
     * 
     * B.RawCount ; 3
     */
    RawCount {
        get {
            static Count := (Object.Prototype.GetOwnPropDesc)(
                Map.Prototype, "Count").Get

            Result := 0
            MapObj := this
            Loop {
                Result += Count(MapObj)
                if (!ObjHasOwnProp(MapObj, "Next")) {
                    break
                }
                MapObj := MapObj.Next
            }
            return Result
        }
    }

    /**
     * Returns an enumerator of all values in the current map, without
     * inheriting keys from parent maps.
     * 
     * @example
     * A := ChainedMap.Base("foo", "bar")
     * B := A.Extend("baz", "qux", "foo", "baz")
     * 
     * B.OwnValues ; <("baz", "qux"), ("foo", "baz")>
     * 
     * @return  {Enumerator}
     */
    OwnValues => (Map.Prototype.__Enum)(this, 2)

    /**
     * Returns an enumerator for the map (see `.__Enum()`).
     * 
     * @example
     * A := ChainedMap.Base("foo", "bar", "hello", "world")
     * B := A.Extend("baz", "qux", "foo", "baz")
     * 
     * B.Values ; <("baz", "qux"), ("foo", "baz"), ("hello", "world")>
     * 
     * @return  {Enumerator}
     */
    Values => this.__Enum(2)

    /**
     * Returns an enumerator for the map. It inherits previously unused keys
     * which it borrows down the chain of base map, and "hides" keys
     * already in use.
     * 
     * @example
     * A := ChainedMap.Base("foo", "bar", "hello", "world")
     * B := A.Extend("baz", "qux", "foo", "baz")
     * 
     * for Key, Value in B.Values {
     *     ; <("baz", "qux"), ("foo", "baz"), ("hello", "world")>
     * }
     * 
     * @param   {Integer}  ArgSize  amount of parameters the for-loop accepts
     * @return  {Enumerator}
     */
    __Enum(ArgSize) {
        MapObj := this
        Items := (Map.Prototype.__Enum)(MapObj)
        Seen := Map()
        Seen.CaseSense := this.CaseSense
        return Enumer

        Enumer(&Key, &Value) {
            Loop {
                while (Items(&Key, &Value)) {
                    if (!Seen.Has(Key)) {
                        Seen.Set(Key, true)
                        return true
                    }
                }
                if (!ObjHasOwnProp(MapObj, "Next")) {
                    return false
                }
                MapObj := MapObj.Next
                Items := (Map.Prototype.__Enum)(MapObj)
            }
        }
    }

    /**
     * Returns an enumerator that iterates all key-value pairs from the current,
     * and down the chain of parent maps.
     * 
     * @example
     * A := ChainedMap.Base("foo", "bar")
     * B := A.Extend("baz", "qux", "foo", "baz")
     * 
     * B.RawValues ; <("baz", "qux"), ("foo", "baz"), ("foo", "bar")>
     */
    RawValues {
        get {
            MapObj := this
            Items := (Map.Prototype.__Enum)(MapObj)
            return Enumer

            Enumer(&Key, &Value) {
                Loop {
                    if (Items(&Key, &Value)) {
                        return true
                    }
                    if (!ObjHasOwnProp(MapObj, "Next")) {
                        return false
                    }
                    MapObj := MapObj.Next
                    Items := (Map.Prototype.__Enum)(MapObj)
                }
            }
        }
    }

    /**
     * Returns a value from the chained map.
     * 
     * @
     * 
     * @param   {Any}  Key  the map key to retrieve value from
     * @return  {Any}
     */
    __Item[Key] {
        get {
            static Prop   := (Object.Prototype.GetOwnPropDesc)
            static __Item := Prop(Map.Prototype, "__Item").Get
            static Has    := Prop(Map.Prototype, "Has").Call
            static Get    := Prop(Map.Prototype, "Get").Call

            MapObj := this
            Loop {
                if (Has(MapObj, Key)) {
                    return Get(MapObj, Key)
                }
                if (!ObjHasOwnProp(MapObj, "Next")) {
                    return __Item(MapObj, Key)
                }
                MapObj := MapObj.Next
            }
        }
    }

    /**
     * Sets a default value to return if a map key cannot be found. This
     * property affects all parent maps.
     * 
     * @param   {Any}  value  the new default value
     */
    Default {
        set {
            static Define := (Object.Prototype.DefineProp)
            MapObj := this

            Loop {
                Define(MapObj, "Default", { Value: value })
                if (!ObjHasOwnProp(MapObj, "Next")) {
                    return
                }
                MapObj := MapObj.Next
            }
        }
    }

    /**
     * Sets the case sensitivity setting of the map, including all of its
     * parents.
     * 
     * @example
     * A := ChainedMap.Base("foo", "bar")
     * B := A.Extend()
     * 
     * B.Get("foo") ; "bar"
     * 
     * @param   {Primitive}  value  the new setting
     */
    CaseSense {
        set {
            static CaseSense := (Object.Prototype.GetOwnPropDesc)(
                Map.Prototype, "CaseSense").Set

            MapObj := this
            
            Loop {
                CaseSense(MapObj, value)
                if (!ObjHasOwnProp(MapObj, "Next")) {
                    return
                }
                MapObj := MapObj.Next
            }
        }
    }

    /**
     * Returns a new chained map that inherits from this map.
     * 
     * @example
     * A := ChainedMap.Base("foo", "bar")
     * B := A.Extend("foo", "baz")
     * 
     * B["foo"] ; "baz"
     * 
     * @param   {Any*}  Args  key-value pairs to add
     * @return  {ChainedMap}
     */
    Extend(Args*) => ChainedMap(this, Args*)


    /**
     * Returns the inheritance chain of maps, including the current map.
     * 
     * @example
     * A := ChainedMap.Base("foo", "bar")
     * B := A.Extend("foo", "baz")
     * C := B.Extend("foo", "qux")
     * 
     * C.Chain ; [C, B, A]
     * 
     * @return  {Array}
     */
    Chain {
        get {
            Chain := Array()
            MapObj := this
            Loop {
                Chain.Push(MapObj)
                if (!ObjHasOwnProp(MapObj, "Next")) {
                    return Chain
                }
                MapObj := MapObj.Next
            }
            return Chain
        }
    }

    /**
     * Returns the root of the chained map (the parent map that has no more
     * parents to inherit from).
     * 
     * @example
     * A := ChainedMap.Base()
     * B := A.Extend()
     * C := B.Extend()
     * C.Root ; A
     * 
     * @return  {Map}
     */
    Root {
        get {
            MapObj := this
            Loop {
                if (!ObjHasOwnProp(MapObj, "Next")) {
                    return MapObj
                }
                MapObj := MapObj.Next
            }
        }
    }

    /**
     * The number of maps in the inheritance chain, including itself.
     * 
     * A root map has a depth of 1. Each additional parent increases depth
     * by 1.
     * 
     * @example
     * A := ChainedMap.Base()
     * B := A.Extend()
     * C := B.Extend()
     * C.Depth ; 3
     * 
     * @return  {Integer}
     */
    Depth {
        get {
            Depth := 1
            MapObj := this
            Loop {
                if (!ObjHasOwnProp(MapObj, "Next")) {
                    return Depth
                }
                MapObj := MapObj.Next
                ++Depth
            }
        }
    }

    /**
     * Creates a new regular map containing all effective key-value pairs from
     * this map and its inheritance chain.
     * 
     * Keys from this map override keys from parent maps. The resulting Map has
     * no connection to the original chain and will not reflect future changes.
     * 
     * @example
     * A := ChainedMap.Base("foo", "bar", "hello", "world")
     * B := A.Extend("baz", "qux", "foo", "baz")
     * C := B.Flatten() ; Map("baz", "qux", "foo", "baz", "hello", "world")
     */
    Flatten() {
        Result := Map()
        Result.CaseSense := this.CaseSense
        if (ObjHasOwnProp(this, "Default")) {
            Result.Default := this.Default
        }

        for Key, Value in this {
            Result.Set(Key, Value)
        }
        return Result
    }
}