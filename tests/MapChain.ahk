#Requires AutoHotkey v2.0

class MapChain {
    static Base(*) {
        A := MapChain.Base("foo", "bar")
    }

    static Extend_static() {
        A := MapChain.Base("foo", "bar")
        B := MapChain.Extend(A, "foo", "baz")
    }

    static Clear() {
        A := MapChain.Base("foo", "bar")
        B := A.Extend()
        B.Clear()

        B.Has("foo").AssertEquals(false)
    }

    static ClearOwn() {
        A := MapChain.Base("foo", "bar")
        B := A.Extend("foo", "baz", "hello", "world")
        B.ClearOwn()
        B.Get("foo").AssertEquals("bar")
        B.Has("hello").AssertEquals(false)
    }

    static Clone() {
        A := MapChain.Base("foo", "baz")
        B := A.Extend("baz", "qux")

        Cloned := B.Clone()

        (Cloned.Next).AssertNotEquals(A)

        Cloned.Get("baz").AssertEquals("qux")
        Cloned.Get("foo").AssertEquals("baz")
    }

    static CloneOwn() {
        A := MapChain.Base("foo", "baz")
        B := A.Extend("baz", "qux")

        Cloned := B.CloneOwn()

        Cloned.Get("baz").AssertEquals("qux")
        Cloned.Get("foo").AssertEquals("baz")
        (Cloned.Next).AssertEquals(A)
    }

    static Delete() {
        A := MapChain.Base("foo", "bar")
        B := A.Extend("foo", "baz")
        B.Delete("foo")
        B.Has("")
    }

    static DeleteOwn() {
        A := MapChain.Base("foo", "bar")
        B := A.Extend("foo", "baz")
        B.DeleteOwn("foo")

        B.Get("foo").AssertEquals("bar")
    }

    static DeleteAll() {
        A := MapChain.Base("foo", "bar")
        B := A.Extend("foo", "baz")

        B.DeleteAll("foo")

        A.HasOwn("foo").AssertEquals(false)
        B.HasOwn("foo").AssertEquals(false)
    }

    static Get() {
        A := MapChain.Base("foo", "bar")
        B := A.Extend()
        
        B.Get("foo").AssertEquals("bar")
    }

    static GetAll() {
        A := MapChain.Base("foo", "bar")
        B := A.Extend("foo", "baz")
        
        B.GetAll("foo").Join(", ").AssertEquals("baz, bar")
    }

    static GetOwn() {
        TestSuite.AssertThrows(GetOwn)

        GetOwn() {
            A := MapChain.Base("foo", "bar")
            B := A.Extend()

            B.GetOwn("foo")
        }
    }

    static Has() {
        A := MapChain.Base("foo", "bar")
        B := A.Extend()

        B.Has("foo").AssertEquals(true)
    }

    static HasOwn() {
        A := MapChain.Base("foo", "bar")
        B := A.Extend()

        B.Has("foo").AssertEquals(true)
        B.HasOwn("foo").AssertEquals(false)
    }

    static OwnCount() {
        A := MapChain.Base("foo", "bar")
        B := A.Extend()
    
        (B.OwnCount).AssertEquals(0)
    }

    static Count() {
        A := MapChain.Base("foo", "bar")
        B := A.Extend("baz", "qux", "foo", "baz") ; "foo" overridden
        (B.Count).AssertEquals(2)
    }

    static RawCount() {
        A := MapChain.Base("foo", "bar")
        B := A.Extend("baz", "qux", "foo", "baz")

        (B.RawCount).AssertEquals(3)
    }

    static OwnValues() {
        A := MapChain.Base("foo", "bar")
        B := A.Extend("baz", "qux", "foo", "baz")

        B.OwnValues.Stream().Join(", ").AssertEquals("baz, foo")
    }

    static Values() {
        A := MapChain.Base("foo", "bar")
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
        A := MapChain.Base("foo", "bar")
        B := A.Extend("baz", "qux", "foo", "baz")

        B.RawValues.Stream()
            .Map(Mapper.Format("{} {}"))
            .Join("; ")
            .AssertEquals("baz qux; foo baz; foo bar")
    }

    static __Item() {
        A := MapChain.Base("foo", "bar")
        A["foo"] := "baz"
        A["foo"].AssertEquals("baz")

        B := A.Extend("baz", "qux")

        B["foo"].AssertEquals("baz")
        B["baz"].AssertEquals("qux")
    }

    static Default_CaseSense() {
        A := MapChain.Base()
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
        A := MapChain.Base()
        B := A.Extend()
        B.Next.AssertEquals(A)
    }

    static Chain() {
        A := MapChain.Base()
        B := A.Extend()
        C := B.Extend()

        ChainExpected := Array(C, B, A)
        ChainActual := C.Chain

        Loop (ChainActual.Length) {
            (ChainActual[A_Index]).AssertEquals(ChainExpected[A_Index])
        }
    }

    static Depth() {
        A := MapChain.Base()
        B := A.Extend()
        C := B.Extend()
        C.Depth.AssertEquals(3)
    }

    static Root() {
        A := MapChain.Base()           
        B := A.Extend()
        C := B.Extend()
        C.Root.AssertEquals(A)
    }

    static Flatten() {
        A := MapChain.Base("foo", "bar", "hello", "world")
        B := A.Extend("baz", "qux", "foo", "baz")
        C := B.Flatten()

        ObjGetBase(C).AssertEquals(Map.Prototype)

        C.Count.AssertEquals(3)
        C.Get("foo").AssertEquals("baz")
    }

    static From(*) {
        Orig := Map("foo", "bar")
        A := MapChain.From(Orig,
                           Map("foo", "baz", "hello", "world"))
        
        Orig["test"] := "123"
        A.Has("test").AssertEquals(true)

        A.Count.AssertEquals(3)
        A.OwnCount.AssertEquals(2)
        A.RawCount.AssertEquals(4)
    }

    static CloneFrom(*) {
        Orig := Map("foo", "bar")
        A := MapChain.CloneFrom(Orig,
                           Map("foo", "baz", "hello", "world"))
        
        Orig["test"] := "123"
        A.Has("test").AssertEquals(false)

        A.Count.AssertEquals(2)
        A.OwnCount.AssertEquals(1)
        A.RawCount.AssertEquals(3)
    }
}