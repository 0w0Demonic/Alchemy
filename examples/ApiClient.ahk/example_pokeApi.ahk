#Requires AutoHotkey v2.0
#Include "%A_LineFile%/../../../ApiClient.ahk"

/**
 * Small example that uses https://pokeapi.co
 */
class PokeApi extends ApiClient {
    /**
     * Pokémon are the creatures that inhabit the world of the ...
     * @param  {Primitive}  Ident  name or id of the pokemon
     */
    static Pokemon[Ident] => {
        Verb: "Get",
        Path: "/pokemon/" . Ident,
        Headers: {
            set_cookie: ["A=B", "C=D"]
        }
    }

    /**
     * Berries are small fruits that can provide HP and status ...
     * @param  {Primitive}  Ident  name or id of the berry
     */
    static Berry[Ident] => {
        Verb: "Get",
        Path: "/berry/" . Ident
    }
}

Client   := PokeApi("https://pokeapi.co/api/v2")
Response := Client.Pokemon["pikachu"]
Output   := JSON.Dump(Response)

Keys := ""
Delim := ", "
for Key in Response {
    Keys .= Key . Delim
}
Keys := "{" . SubStr(Keys, 1, -StrLen(Delim))

MsgBox(Format("
    (
    Output: "{}"
    Keys: {}
    )",
    SubStr(Output, 1, 60) . "...",
    SubStr(Keys, 1, 60) . "...",
), "ApiClient.ahk - TEST #1")

; {"abilities":[{"ability":{"name":"static","url":"https://pokeapi/ ...