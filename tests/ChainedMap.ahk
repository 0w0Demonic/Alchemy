#Requires AutoHotkey v2.0

class ChainedMap {
    static Base(*) {
        A := ChainedMap.Base("foo", "bar")
    }

    static Extend_static() {
        A := ChainedMap.Base("foo", "bar")
        B := ChainedMap.Extend(A, "foo", "baz")
    }

    static Clear() {
        A := ChainedMap.Base("foo", "bar")
        B := A.Extend()
        B.Clear()

        B.Has("foo").AssertEquals(false)
    }

    static ClearOwn() {
        A := ChainedMap.Base("foo", "bar")
        B := A.Extend("foo", "baz", "hello", "world")
        B.ClearOwn()
        B.Get("foo").AssertEquals("bar")
        B.Has("hello").AssertEquals(false)
    }

    static Clone() {
        A := ChainedMap.Base("foo", "baz")
        B := A.Extend("baz", "qux")

        Cloned := B.Clone()

        (Cloned.Next).AssertNotEquals(A)

        Cloned.Get("baz").AssertEquals("qux")
        Cloned.Get("foo").AssertEquals("baz")
    }

    static CloneOwn() {
        A := ChainedMap.Base("foo", "baz")
        B := A.Extend("baz", "qux")

        Cloned := B.CloneOwn()

        Cloned.Get("baz").AssertEquals("qux")
        Cloned.Get("foo").AssertEquals("baz")
        (Cloned.Next).AssertEquals(A)
    }

    static Delete() {
        A := ChainedMap.Base("foo", "bar")
        B := A.Extend("foo", "baz")
        B.Delete("foo")
        B.Has("")
    }

    static DeleteOwn() {
        A := ChainedMap.Base("foo", "bar")
        B := A.Extend("foo", "baz")
        B.DeleteOwn("foo")

        B.Get("foo").AssertEquals("bar")
    }

    static DeleteAll() {
        A := ChainedMap.Base("foo", "bar")
        B := A.Extend("foo", "baz")

        B.DeleteAll("foo")

        A.HasOwn("foo").AssertEquals(false)
        B.HasOwn("foo").AssertEquals(false)
    }

    static Get() {
        A := ChainedMap.Base("foo", "bar")
        B := A.Extend()
        
        B.Get("foo").AssertEquals("bar")
    }

    static GetAll() {
        A := ChainedMap.Base("foo", "bar")
        B := A.Extend("foo", "baz")
        
        B.GetAll("foo").Join(", ").AssertEquals("baz, bar")
    }

    static GetOwn() {
        TestSuite.AssertThrows(GetOwn)

        GetOwn() {
            A := ChainedMap.Base("foo", "bar")
            B := A.Extend()

            B.GetOwn("foo")
        }
    }

    static Has() {
        A := ChainedMap.Base("foo", "bar")
        B := A.Extend()

        B.Has("foo").AssertEquals(true)
    }

    static HasOwn() {
        A := ChainedMap.Base("foo", "bar")
        B := A.Extend()

        B.Has("foo").AssertEquals(true)
        B.HasOwn("foo").AssertEquals(false)
    }

    static OwnCount() {
        A := ChainedMap.Base("foo", "bar")
        B := A.Extend()
    
        (B.OwnCount).AssertEquals(0)
    }

    static Count() {
        A := ChainedMap.Base("foo", "bar")
        B := A.Extend("baz", "qux", "foo", "baz") ; "foo" overridden
        (B.Count).AssertEquals(2)
    }

    static RawCount() {
        A := ChainedMap.Base("foo", "bar")
        B := A.Extend("baz", "qux", "foo", "baz")

        (B.RawCount).AssertEquals(3)
    }

    static OwnValues() {
        A := ChainedMap.Base("foo", "bar")
        B := A.Extend("baz", "qux", "foo", "baz")

        B.OwnValues.Stream().Join(", ").AssertEquals("baz, foo")
    }

    static Values() {
        A := ChainedMap.Base("foo", "bar")
        B := A.Extend("baz", "qux", "foo", "baz")

        Count := 0
        for Key, Value in B.Values {
            ++Count
            if (Key == "baz") {
                Value.AssertEquals("qux")
            }
            if (Key == "foo") {
                Value.AssertEquals("baz")
            }
        }
        Count.AssertEquals(2)
    }

    static RawValues() {
        A := ChainedMap.Base("foo", "bar")
        B := A.Extend("baz", "qux", "foo", "baz")

        B.RawValues.Stream()
            .Map(Mapper.Format("{} {}"))
            .Join("; ")
            .AssertEquals("baz qux; foo baz; foo bar")
    }

    static __Item() {
        A := ChainedMap.Base("foo", "bar")
        A["foo"] := "baz"
        A["foo"].AssertEquals("baz")

        B := A.Extend("baz", "qux")

        B["foo"].AssertEquals("baz")
        B["baz"].AssertEquals("qux")
    }

    static Default_CaseSense() {
        A := ChainedMap.Base()
        B := A.Extend()
        C := B.Extend()

        C.Default := "(empty)"
        C.CaseSense := "Off"

        Array(C.Default, B.Default, A.Default)
            .Join(", ")
            .AssertEquals("(empty), (empty), (empty)")

        Array(C.CaseSense, B.CaseSense, A.CaseSense)
            .Join(", ")
            .AssertEquals("Off, Off, Off")
    }

    static Extend(*) {
        A := ChainedMap.Base()
        B := A.Extend()
        B.Next.AssertEquals(A)
    }

    static Chain() {
        A := ChainedMap.Base()
        B := A.Extend()
        C := B.Extend()

        ChainExpected := Array(C, B, A)
        ChainActual := C.Chain

        Loop (ChainActual.Length) {
            (ChainActual[A_Index]).AssertEquals(ChainExpected[A_Index])
        }
    }

    static Depth() {
        A := ChainedMap.Base()
        B := A.Extend()
        C := B.Extend()
        C.Depth.AssertEquals(3)
    }

    static Root() {
        A := ChainedMap.Base()           
        B := A.Extend()
        C := B.Extend()
        C.Root.AssertEquals(A)
    }

    static Flatten() {
        A := ChainedMap.Base("foo", "bar", "hello", "world")
        B := A.Extend("baz", "qux", "foo", "baz")
        C := B.Flatten()

        ObjGetBase(C).AssertEquals(Map.Prototype)

        C.Count.AssertEquals(3)
        C.Get("foo").AssertEquals("baz")
    }
}