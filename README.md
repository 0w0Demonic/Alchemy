# Alchemy

```
 `.     . o               x     . _  *
   ,_._     _,-'""`-._        .
 `<_,-.`._,'(    .  |\`-/|        ´ _|_
       `-.-' \.)-`( , o o)__      * .'
  .  `       `-    \, `"'\_    `
```

This repository contains a variety of AHK v2 utilities that really bring OOP
down to its knees. You will find things like:

- API client generators
- self-generating enum classes
- cascading objects and classes (like CSS selectors)
- "map chains" (note: these are *really* cool)
- object viewer tools
- and a wide variety of other oddities

These are some things that I've written over time for my larger projects,
presented to you as (mostly) standalone scripts.

I feel like they deserve a place on their own because of their unique style.
AutoHotkey v2's object protocol has a place in my heart, and it allows for some
really cool patterns that are impossible in other languages.

That aside, let this be your "magic spellbook" of utils, and have fun looking
around.

## Map Chains

Our first little exhibit of this repo is the `MapChain` type. It's a special
type of map that can optionally be linked to a "parent" map. Whenever a key
lookup fails, the map will continue its search in the parent map, and so on.

If you need tree-like structures, or map entries that you can override in
certain contexts, this might be the perfect thing for you.

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

Another way to create a map chain is to use the `MapChain.From()` and
`MapChain.CloneFrom()`

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
modeled closely after AutoHotkey’s built-in `Map`, but `MapChain` includes
extra properties and methods to help distinguish between inherited and direct
entries. `Own[...]`, for example, narrows the scope to just that particular
map. As an example:

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

I think the rest will speak for itself when looking through the doc comments,
and I'm hoping you can build something fun out of this; as much as I myself had
fun putting this together.

## Cascades

`Cascade`, originally meant for making context-based theme objects, can
be used to create objects that participate in a "cascading behavior".

Objects inside this structure fall back to their sibling objects with the same
name, e.g.:

```ahk
Theme := {
    Button: {
        Font: { ; <-- this object...
            Name: "Cascadia Code"
        }
    },
    Font: { ; <-- ...inherits from this object!
        Size: 12
    }
} ; <-- ...and then finally from the root.

Cascade.Transform(Theme) ; alternatively: `Theme := Cascade.Create(Theme)`

Font := Theme.Button.Font
MsgBox(Font.Name) ; "Cascadia Code" ; pun not intended, it's a good font fr.
MsgBox(Font.Size) ; 12
```

Create a new cascade by using `Cascade.Create(Obj)` or `Cascade.Transform(Obj)`:

```ahk
Theme := { ... }

Obj := Cascade.Create(Theme) ; create a clone
Cascade.Transform(Theme)     ; change in place
```

Use `ClassCascade`, when working with classes. Works exactly the same, except
that using it as base will automatically `.Transform()` it for you.

```ahk
class Theme extends ClassCascade {
    class Button {
        class Font {
            Name => "Cascadia Code"
        }
    }
    class Font {
        Size => 12
    }
}
ButtonTheme := Theme.Button
Font := ButtonTheme.Font()
MsgBox(ButtonTheme.Size) ; 12
```

## API Mapper

This class builds a simple API client based on metadata. It allows you to
describe REST-like APIs in a very convenient manner that is declarative and
reusable.

### Dependencies

- `cJson.ahk` by G33kDude ([GitHub](https://github.com/G33kDude/cJson.ahk))
- `WinHttpClient.ahk` by thqby ([GitHub](https://github.com/thqby/ahk2_lib/blob/master/WinHttpRequest.ahk))

### How it Works

To define an API client, you extend `ApiClient` and describe each endpoint using
static properties. Each property corresponds to an API call and returns a small
object describing how to make the request.

This object **must** contain:

- `Verb` (HTTP verb like "GET", "POST", etc.)
- `Path` (relative URL fragment, e.g. `"/users/12345"`)

You'll be able to add more optional stuff later (I'm having
[big plans](#roadmap) here...), but at minimum these two
are required.

```ahk
class JsonPlaceholder extends ApiClient {
    static Test => {
        Verb: "Get",
        Path: "/todos/1"
    }
}

Client := JsonPlaceHolder("https://jsonplaceholder.typicode.com")
Client.Test() ; "{ "userId": 1, ... }"
```

Here, `Test` is just a static property describing a request `GET /todos/1`.
When the `JsonPlaceholder` class loads, it turns those descriptions into
*methods*.

### Parameterized Endpoints

Properties can be parameterized, to interpolate into the endpoint path, or
to set certain query strings and and headers:

```ahk
class PokeApi extends ApiClient {
    ; static Pokemon(Ident) { ... } is fine, too.
    static Pokemon[Ident] => {
        Verb: "Get",
        Path: "/pokemon/" . Ident,
    }
}
```

This is extremely useful for whenever the path is not fixed, but depends on
external parameters.

```ahk
Api := PokeApi("https://pokeapi.co/api/v2")
Api.Pokemon["pikachu"]() ; {"abilities":[{"ability": ... }]}
```

### Query Strings and Headers

Query strings and headers can be added by an object with key/value pairs like
this:

```ahk
class ExampleApi extends ApiClient {
    static GetUser[id, name] => {
        Verb: "Get",
        Path: "/users",
        Query: {
            id: id,
            name: name
        },
        Headers:
    }
}

; resolves to `https://www.example.com/users?id=734?name=foo`
Api := ExampleApi("https://www.example.com/api/v2")
Api.GetUser[734, "foo"]()
```

Accepted values:

- Maps
- Arrays (elements of alternating key/value)
- Objects

To be able to pass keys that contains hyphens (which AHK doesn't allow as
valid symbol), you'll need to use Maps instead of plain objects. For query
and header keys that are used multiple times, you'll need to use arrays.

```ahk
; as map
Query: Map("weird-key-name", "value")

; as array
Headers: ["Set-Cookie", "foo", "Set-Cookie", "bar"]
```

### Payload in POST/PUT

Some HTTP methods accept a payload to be sent. This is determined by the
`static Verbs` property of each `ApiClient` subclass.

Whenever an endpoint is both variable (i.e., if it's parameterized) and accepts
a payload, it must be "called twice":

```ahk
class ExampleApi extends ApiClient {
    static UpdateUser[Id] => {
        Path: "/Users/" . Id
        Verb: "POST"
    }
}

Client := ExampleApi("https://www.example.com")

Client.UpdateUser[123]("{ id: 123, name: ... }")

; alternatively, if `UpdateUser` was defined as method:
Client.UpdateUser(123)("{ ... }")
```

### Roadmap

#### Validation and Data Binding

An object that describes expected types and structure of the JSON. They should
be able to validate both request and response body, and convert values into the
correct representation. Here's roughly how it should look like:

```ahk
; channel ID, followed by an array of user objects
ExpectedParams := Schema({
    channel: Integer,
    users: Array({
        id: Mandatory(Integer),
        name: Mandatory(String),
        nickname: String
    })
})

ApiResult := Schema( ... )

class Example extends ApiClient {
    static RemoveUsers => {
        Verb: "Post",
        Path: "/users/..."
        Parameters: ExpectedParams,
        ReturnType: ApiResult
    }
}
Client := Example("https://www.example.com/api/v2")
; ...
Client.RemoveUsers(...) ; ApiResult{ ... }
```
