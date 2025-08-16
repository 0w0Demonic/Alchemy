# Alchemy

```
 `.     . o               x     . _  *
   ,_._     _,-'""`-._        .
 `<_,-.`._,'(    .  |\`-/|        ´ _|_
       `-.-' \.)-`( , o o)__      * .'
  .  `       `-    \, `"'\_    `
```

This repository contains a variety of AHK v2 utilities that really bend OOP
down to its knees. You will find things like:

- API client generators
- self-generating enum classes
- cascading objects and classes (like CSS selectors)
- "chained maps" (note: these are *really* cool)
- object viewer tools
- and a wide variety of other oddities

These are some things that I've written over time for my larger projects,
presented to you as (mostly) standalone scripts.

I feel like they deserve a place on their own because of their unique style.
AutoHotkey v2's object protocol has a place in my heart, and it allows for some
really cool patterns that are impossible in other languages.

That aside, let this be your "magic spellbook" of utils, and have fun looking
around.

## Chained Maps

Our first little exhibit of this repo is the `ChainedMap` type. It's a special
type of map that can optionally be linked to a "parent" map. Whenever a key
lookup fails, the map will continue its search in the parent map, and so on.

If you need tree-like structures, or map entries that you can override in
certain contexts, this might be the perfect thing for you.

To create a new chained map, start by creating the "root map" like this:

```ahk
A := ChainedMap.Base("foo", "bar", "hello", "world!")
```

Then, you can create a second map that builds on the previous one:

```ahk
B := A.Extend("foo", "baz", "apple", "banana")

; alternatives:
; B := ChainedMap.Extend(A, ...)
; B := ChainedMap(A, ...)
```

You'll end up with a map that can inherit from its parent.

```ahk
B["hello"] ; "world"
```

Notice that we've just overridden the key-value pair behind `"foo"`. Although
this entry is still present inside of the parent map (`A`), the deriving map
defines its own entry.

```ahk
A["foo"] ; "bar"
B["foo"] ; "baz"
```

You can build surprisingly elaborate structures with this. The interface is
modeled closely after AutoHotkey’s built-in `Map`, but `ChainedMap` includes
extra properties and methods to help distinguish between inherited and direct
entries. For instance, `Own[...]` narrows the scope to just that particular
map. As an example:

```ahk
B.HasOwn("foo") ; explicitly searches `B`, without falling back to its parent
```

Beyond that, there are a few methods unique to chained maps:

- `.Chain()`: returns an array of all maps in the inheritance chain,
  starting from the current map and moving up.
- `.Root`: gives back the top-most map in the chain.
- `.Depth`: the number of maps in the chain, including the current one.
- `.Flatten()`: produces a plain map containing all top-level keys,
  with later maps in the chain overriding earlier ones.

I think the rest will speak for itself when looking through the doc comments,
and I'm hoping you can build something fun out of this; as much as I myself had
fun putting this together.

---
