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

*A map with prototype-style inheritance*.

```ahk
A := MapChain.Base("foo", "bar", "hello", "world")
B := A.Extend("foo", "bar!!!", "apple", "banana")

B["foo"]   ; "bar!!!"
B["apple"] ; "banana"
B["hello"] ; "world"
```

These maps can optionally be linked a to a "parent" map to fall back to,
whenever a key lookup fails. The map will then continue its search down the
chain of parents.

Originally, I needed this class for my
[Yako](https://www.github.com/0w0Demonic/Yako) repository to hold a collection
of callback functions. It had to be:

- accessible via message number;
- overridable in further subclasses;
- dynamic (simply add to the map for a visible change).

This worked *extremely* well, which is why I've taken the time to write a
much more sophisticated version to showcase here.

If you need hierarchical structures similar to this, it might be *the*
ideal thing for you <sub>(maybe even tree-like? I should test this
out...)</sub>.

See also:

- [docs](./docs/MapChain.md)

## Cascades

`Cascade`, originally meant for making context-based theme objects, can
be used to create objects that participate in a "cascading behavior".

Objects inside this structure fall back to their enclosing objects.

```ahk
Theme := Cascade({
    Button: {
        font_name: "Cascadia Code" ; pun not intended
    },
    font_size: 12
})

MsgBox(Theme.Button.font_name) ; "Cascadia Code"
MsgBox(Theme.Button.font_size) ; 12
```

Use `ClassCascade`, when working with classes. Works exactly the same, except
that using it as base will automatically `.Transform()` it for you.

```ahk
class Theme extends ClassCascade {
    class Button {
        Font_Name => "Cascadia Code"
    }
    Font_Size => 12
}
ButtonTheme := Theme.Button()

MsgBox(ButtonTheme.Font_Name) ; "Cascadia Code"
MsgBox(ButtonTheme.Font_Size) ; 12
```

## API Mapper

This class builds a simple API client based on metadata. It allows you to
describe REST-like APIs in a very convenient manner that is declarative and
reusable.

To define an API client, you extend `ApiClient` and describe each endpoint using
static properties.

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

- `Verb` (HTTP verb like `GET`, `POST`, etc.)
- `Path` (relative URL fragment, e.g. `"/users/12345"`)

Properties can be parameterized, to interpolate into the endpoint path, or
to set certain query strings and and headers:

```ahk
class ExampleApi extends ApiClient {
    static GetUser[id, name] => {
        Verb: "Get",
        Path: "/users",
        Query: {
            id: id,
            name: name
        },
        Headers: {
            accept: "application/json"
            ; when using plain objects, this is converted to "set-cookie"
            set_cookie: "foo=bar"
        }
    }
}
; GET /users
; query: "?id=734&name=foo"
; headers: "accept: application/json; set_cookie: foo=bar"
...
Client.GetUser[734, "foo"]
```

See also:

- [docs](./docs/ApiClient.md)