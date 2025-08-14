#Requires AutoHotkey v2

/**
 * A data structure that resembles a chain of maps connected together.
 */
class CascadingMap extends Map {
    /**
     * Returns a new cascading map with the given base map to inherit from.
     * 
     * @param   {Map?}  Next  base map to inherit from
     * @return  {CascadingMap}
     */
    __New(Next := Map()) {
        if (!(Next is Map)) {
            throw TypeError("Expected a Map",, Type(Next))
        }

        (Object.Prototype.DefineProp)(this, "Next", { Get: (_) => Next })
    }

    /**
     * Returns an enumerator for the map which inherits previously unused
     * keys borrowed down the chain of base maps, and "hides" already-used keys
     * higher up the inheritance chain.
     * 
     * @param   {Integer}  ArgSize  amount of parameters the for-loop accepts
     * @return  {Enumerator}
     */
    __Enum(ArgSize) {
        ; TODO there's probably a better way to do this and just return
        ; an own enumerator, instead of flattening out everything. That way
        ; we're getting new properties lazily.
        Result := Map()
        Result.CaseSense := this.CaseSense

        MapObj := this
        Loop {
            ; I wish `for Key, Value in super` would work, that'd be cool.
            for Key, Value in (Map.Prototype.__Enum)(MapObj) {
                if (!Result.Has(Key)) {
                    Result.Set(Key, Value)
                }
            }
            if (!ObjHasOwnProp(MapObj, "Next")) {
                break
            }
            MapObj := MapObj.Next
        }
        return Result.__Enum(ArgSize)
    }

    /**
     * Returns a value from the cascading map.
     * 
     * @param   {Any}   Key      the map key to retrieve value from
     * @param   {Any?}  Default  default value to return
     * @return  {Any}
     */
    Get(Key, Default?) {
        return super.Get(Key, Default?) || this.Next.Get(Key, Default?)
    }

    /**
     * 
     */
    __Item[Key] => super[Key] || (this.Next)[Key]

    /**
     * Returns a new cascading map that inherits from this map.
     * 
     * @return  {CascadingMap}
     */
    Subclass() => CascadingMap(this)
}