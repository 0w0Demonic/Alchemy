# MapChain

Map chains are maps that can be linked to *parent maps*. Whenever a key lookup
fails (i.e., `.Get()`, `.Has()`, etc.), the map will continue its search in
the parent map, and so on.

Essentially, inheritance.

**Create Map Chains**:

To create a new map chain, start by creating the "root map" like this:

```ahk
A := MapChain.Base("foo", "bar", "hello", "world!")
```

Then, you can create a second map that builds on the previous one:

```ahk
B := A.Extend("foo", "baz", "apple", "banana")

; alternatives:
; B := MapChain.Extend(A, ...)
; B := MapChain(A, ...)
```

Another (interesting) way to create a map chain is to use the
`MapChain.From(Maps*)` and `MapChain.CloneFrom(Maps*)`. That way, you can first
use multiple maps independently and afterwards connect them all into a map
chain.

```ahk
; A inherits from B, B inherits from C, ...
Chained := MapChain.From(A, B, C, ...)

; `.CloneFrom(Maps*)` creates a clone of all the maps
Chained := MapChain.CloneFrom(A, B, C, ...)
```

**Retrieving Values**:

The regular Map functions (`.Has()`, `.Get()`, etc.) now work with "inheritance"
to the parent map.

```ahk
A := MapChain.Base("hello", "world")
B := A.Extend()

B["hello"] ; "world"
```

If the key exists somewhere higher up the chain, it's effectively "overridden".

```ahk
A := MapChain.Base("foo", "bar")
B := A.Extend("foo", "baz")

A["foo"] ; "bar"
B["foo"] ; "baz"
```

**Extra Properties and Methods**:

`MapChain` includes extra properties and methods to help distinguish between
inherited and direct entries. `Own[...]`, for example, narrows the scope
to just that particular map. As an example:

```ahk
B.HasOwn("foo") ; explicitly searches `B`, without falling back to its parent
```

Beyond that, there are a few methods unique to map chains:

- `.Chain`: returns an array of all maps in the inheritance chain,
  starting from the current map and moving up.
- `.Root`: gives back the top-most map in the chain.
- `.Depth`: the number of maps in the chain, including the current one.
- `.Flatten()`: produces a plain map containing all top-level keys,
  with later maps in the chain overriding earlier ones.

```ahk
A := MapChain.Base()
B := A.Extend()
C := B.Extend()

C.Chain ; [C, B, A]
C.Root ; A
C.Depth ; 3
C.Flatten() ; { regular map with all top-level entries }
```
