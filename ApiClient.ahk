#Requires AutoHotkey v2
#Include <JSON>           ; /G33kDude/cJson.ahk
#Include <WinHttpRequest> ; /thqby/ahk2_lib
; #Include <AquaHotkeyX>

/**
 * Base class for building API clients based on metadata.
 * 
 * @example
 * class PokeApi extends ApiClient {
 *     static Pokemon[Ident] => {
 *         Method: "Get",
 *         Path: "/pokemon/" . Ident
 *     }
 * }
 * Api := PokeApi()
 * Api.Pokemon["pikachu"]() ; {"abilities":[{"ability":{"name": ...
 * 
 * @description
 * Subclasses declare endpoints as static properties with declarative
 * metadata (method, path, etc.), which are then exposed as callable
 * members on client instances.
 * 
 * This allows you to describe REST-like APIs in a concise, declarative
 * style instead of hand-writing boilerplate for each request.
 * 
 * An endpoint has to return an object with two mandatory fields
 * `.Method` (a HTTP method) and `.Path` (path relative to the base URL).
 * More are coming very soon.
 * 
 * @example
 * static Pokemon[Ident] => {
 *     Method: "Get",
 *     Path: "/pokemon/" . Ident
 * }
 * 
 * @description
 * Each property can be parameterized (`Ident` in the previous example),
 * where keys are automatically interpolated into the endpoint path.
 * 
 * Whenever the endpoint is parameterized, it needs to be called twice.
 * The first time to resolve a specification for the endpoint, the second
 * time for sending the actual request (for POST-requests, this accepts
 * the payload to be sent).
 * 
 * @example
 * Client := PokeApi("https://pokeapi.co/api/v2")
 * Client.Pokemon["lycanroc-midday"]()
 * 
 * @description
 * Valid property types of endpoints include:
 * 
 * - fields (`static Foo := { ... }`)
 * - getters (`static Foo => { ... }` or `static Foo[Bar] => { ... }`)
 * - methods (`static Foo(Args*) => { ... }`)
 */
class ApiClient extends WinHttpRequest {
    /**
     * Creates a new `ApiClient` instance from the given base URL and,
     * optionally, a user agent to be used.
     * 
     * @param   {String}   BaseUrl    base url of the API
     * @param   {String?}  UserAgent  user agent to be used by the client
     */
    __New(BaseUrl, UserAgent?) {
        super.__New(UserAgent?)

        if (!(BaseUrl is String)) {
            throw TypeError("Expected a String",, Type(BaseUrl))
        }
        this.DefineProp("BaseUrl", { Get: (_) => BaseUrl })
    }

    /** Static init. */
    static __New() {
        static Prop   := (Object.Prototype.GetOwnPropDesc)
        static Define := (Object.Prototype.DefineProp)
        static Delete := (Object.Prototype.DeleteProp)

        ; I'm sorry for you reading this. Will refactor later, though.
        ; ...I think
        static CreateVariableUrlEndpoint(Callback) {
            return VariableUrlEndpoint

            VariableUrlEndpoint(Client, Args*) {
                Endpoint := Callback(Client, Args*)
                return HttpReq

                HttpReq(PostData?) {
                    return Request(Client, Endpoint, PostData?)
                }
            }
        }

        static CreateFixedUrlEndpoint(Endpoint) {
            return CreateFixedUrlEndpoint

            CreateFixedUrlEndpoint(Client, PostData?) {
                return Request(Client, Endpoint, PostData?)
            }
        }

        static CreateNoArgGetter(Getter) {
            return NoArgGetter

            NoArgGetter(Client, PostData?) {
                return Request(Client, Getter(Client), PostData?)
            }
        }

        if (this == ApiClient) {
            return
        }
        for PropName in ObjOwnProps(this) {
            switch (PropName) {
                case "Prototype", "__Init": continue
            }
            
            PropDesc := Prop(this, PropName)
            Endpoint := PrepareEndpoint(PropDesc)
            Define(this.Prototype, PropName, Endpoint)
        }

        static PrepareEndpoint(PropDesc) {
            switch {
                case (ObjHasOwnProp(PropDesc, "Value")):
                    return {
                        Call: CreateFixedUrlEndpoint(PropDesc.Value)
                    }
                case (ObjHasOwnProp(PropDesc, "Get")):
                    if (PropDesc.Get.MinParams > 0) {
                        return {
                            Get: CreateVariableUrlEndpoint(PropDesc.Get)
                        }
                    }
                    return {
                        Call: CreateNoArgGetter(PropDesc.Get)
                    }
                case (ObjHasOwnProp(PropDesc, "Call")):
                    return {
                        Call: CreateVariableUrlEndpoint(PropDesc.Call)
                    }
                default: throw ValueError("Invalid property")
            }
        }

        static Request(Client, Endpoint, PostData?) {
            if (!ObjHasOwnProp(Endpoint, "Path")) {
                throw UnsetError("Missing property: Path")
            }
            if (!ObjHasOwnProp(Endpoint, "Method")) {
                throw UnsetError("Missing property: Method")
            }

            URL := Client.BaseUrl . Endpoint.Path
            if (IsSet(PostData) && !(PostData is String)) {
                PostData := JSON.Dump(PostData)
            }
            Response := Client.Request(URL, Endpoint.Method)
            return JSON.Load(Response)
        }
    }
}

/**
 * A declarative schema object for describing expected types and structures
 * in API responses (or any JSON-like data).
 * 
 * TypeTokens are used for validation and data binding, similar in spirit
 * to frameworks like Jackson (Java) or Pydantic (Python).
 * 
 * They make it possible to assert that incoming data matches the declared
 * structure, or to transform values into the correct representation.
 * 
 * This is gonna be hell...
 * 
 * @example
 * ; an array of objects with fields "id", "name",
 * ; and optionally "nickname"
 * Array({
 *     id: Mandatory(Integer),
 *     name: Mandatory(String),
 *     nickname: String
 * })
 */
class TypeToken {
    static Transform(Obj) {
        ; (TODO)
    }
}

; <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

/**
 * Small example that uses https://pokeapi.co
 */
class PokeApi extends ApiClient {
    /**
     * Pokémon are the creatures that inhabit the world of the ...
     * @param  {Primitive}  Ident  name or id of the pokemon
     */
    static Pokemon[Ident] => {
        Method: "Get",
        Path: "/pokemon/" . Ident
    }

    /**
     * Berries are small fruits that can provide HP and status ...
     * @param  {Primitive}  Ident  name or id of the berry
     */
    static Berry[Ident] => {
        Method: "Get",
        Path: "/berry/" . Ident
    }
}
Api      := PokeApi("https://pokeapi.co/api/v2")
Response := Api.Pokemon["pikachu"]()

; {"abilities":[{"ability":{"name":"static","url":"https://pokeapi/ ...""
MsgBox(JSON.Dump(Response))