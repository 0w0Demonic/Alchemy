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
 *         Verb: "Get",
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
 * `.Verb` (a HTTP method) and `.Path` (path relative to the base URL).
 *  
 * @example
 * static Pokemon[Ident] => {
 *     Verb: "Get",
 *     Path: "/pokemon/" . Ident
 * }
 * 
 * @description
 * Use the `Query` property to create a query string to be used in the request:
 * 
 * @example
 * static GetUser[id, name] => {
 *     Verb: "Get",
 *     Path: "/users",
 *     Query: {
 *         id: id,
 *         name: name
 *     }
 * }
 * 
 * ; resolves to `.../users?id=734?name=foo`
 * Api.GetUser[734, "foo"]()
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

    /**
     * Creates a parameterized method that accesses an API endpoint by first
     * resolving the endpoint specification using a callback function, then
     * either sends an HTTP request directly (if the HTTP method accepts no
     * body), otherwise returns an intermediate closure to accept the payload
     * before sending the request.
     * 
     * @param  {Func}  Callback  property that returns an endpoint to be used
     */
    static CreateVariableUrlEndpoint(Callback) {
        return VariableUrlEndpoint

        /**
         * Resolves an endpoint by calling a callback function. If the endpoint
         * accepts a body, a closure is returned to accept the payload before
         * finally sending an HTTP request. Otherwise, this method sends an
         * HTTP request with no body.
         * 
         * @param   {Any*}  Args  zero or more arguments
         * @return  {Any}
         */
        VariableUrlEndpoint(Client, Args*) {
            Endpoint := Callback(Client, Args*)
            if (!ObjHasOwnProp(Endpoint, "Verb")) {
                throw UnsetError('Missing "Verb" property')
            }
            Verb := Endpoint.Verb
            if (!(Verb is String)) {
                throw TypeError("Expected a String",, Type(Verb))
            }
            if (!Client.Verbs.Has(Verb)) {
                throw ValueError("Invalid HTTP verb",, Verb)
            }
            if (!Client.Verbs.Get(Verb)) {
                return Request(Client, Endpoint)
            }
            return HttpReqWithPayload

            /**
             * Sends an HTTP request with the given payload to be sent.
             * 
             * @param   {Any?}  Payload  the data to be sent
             * @return  {Object}
             */
            HttpReqWithPayload(Payload?) {
                return Request(Client, Endpoint, Payload?)
            }
        }
    }

    /**
     * Creates a function that uses a fixed endpoint to create HTTP requests.
     * 
     * @param   {Object}  Endpoint  the specified endpoint
     * @return  {Closure}
     */
    static CreateFixedUrlEndpoint(Endpoint) {
        return HttpReqWithPayload

        /**
         * Sends an HTTP request with the given payload to be sent.
         * 
         * @param   {Any?}  Payload  the data to be sent
         * @return  {Object}
         */
        HttpReqWithPayload(Client, Payload?) {
            return Request(Client, Endpoint, Payload?)
        }
    }

    /**
     * Creates a function that uses an endpoint returned by the given
     * getter function.
     * 
     * @param   {Func}  Getter  getter method that retrieves an endpoint
     * @return  {Closure}
     */
    static CreateNoArgGetter(Getter) {
        return NoArgGetter

        /**
         * Sends an HTTP request using an endpoint returned by a getter
         * function.
         * 
         * @param   {Any?}  Payload  the data to be sent
         * @return  {Object}
         */
        NoArgGetter(Client, Payload?) {
            return Request(Client, Getter(Client), Payload?)
        }
    }

    /**
     * Creates a new property descriptor to be used as API endpoint,
     * from the given input property descriptor previously defined by the user.
     * 
     * @param   {Object}  PropDesc  previously defined property
     * @return  {Object}
     */
    static PrepareEndpoint(PropDesc) {
        switch {
            case (ObjHasOwnProp(PropDesc, "Value")):
                return { Call: CreateFixedUrlEndpoint(PropDesc.Value) }
            case (ObjHasOwnProp(PropDesc, "Get")):
                return (PropDesc.Get.MinParams > 0)
                    ? { Get: CreateVariableUrlEndpoint(PropDesc.Get) }
                    : { Call: CreateNoArgGetter(PropDesc.Get) }
            case (ObjHasOwnProp(PropDesc, "Call")):
                return (PropDesc.Call.MinParams > 0)
                    ? { Call: CreateVariableUrlEndpoint(PropDesc.Call) }
                    : { Call: CreateNoArgGetter(PropDesc.Call) }
            default: throw ValueError("Invalid property")
        }
    }

    /**
     * Sends an HTTP request and returns the deserialized HTTP response.
     * 
     * @param   {Object}  Endpoint  specifies the type of request to be sent
     * @param   {Any?}    Payload   data to be sent
     * @return  {Object}
     */
    static Request(Client, Endpoint, Payload?) {
        if (!ObjHasOwnProp(Endpoint, "Path")) {
            throw UnsetError("Missing property: Path")
        }
        Path    := Endpoint.Path
        Verb    := Endpoint.Verb
        Headers := (ObjHasOwnProp(Endpoint, "Headers"))
                    ? Endpoint.Headers
                    : {}

        URL := Client.BaseUrl . Path
        if (ObjHasOwnProp(Endpoint, "Query")) {
            Query := Endpoint.Query
            if (!IsObject(Query)) {
                throw TypeError("Expected an Object",, Type(Query))
            }
            for Key, Value in GetEnumerator(Query) {
                URL .= (A_Index == 1) ? "?" : "&"
                URL .= UrlEncode(Key) . "=" . UrlEncode(Value)
            }
        }

        if (IsSet(Payload) && !(Payload is String)) {
            Payload := JSON.Dump(Payload)
        }

        ; Ad-hoc object that returns our specified enumerator
        ; when `.OwnProps()` is called inside the `.Request() method.
        Enumer  := GetEnumerator(Headers)
        Headers := Object()
        (Object.Prototype.DefineProp)(Headers, "OwnProps", {
            Call: (_) => Enumer
        })

        Response := Client.Request(URL, Verb, Payload?, Headers)
        return JSON.Load(Response)
    }

    /**
     * Returns an URL-encoded version of the given string.
     * 
     * @param   {String}  Str  a string to be encoded
     * @return  {String}
     */
    static UrlEncode(Str) {
        Result := ""
        Loop Parse Str {
            switch {
                case (A_LoopField ~= "[A-Za-z0-9\-\.-~]"):
                    Result .= A_LoopField
                case (A_LoopField == " "):
                    Result .= "+"
                default:
                    Result .= "%" . Format("{:02X}", Ord(A_LoopField))
            }
        }
        return Result
    }

    /**
     * Returns an appropriate 2-argument Enumerator for an object.
     * 
     * @param   {Object}  Obj  any object
     * @return  {Enumerator}
     */
    static GetEnumerator(Obj) {
        switch {
            case (Obj is Array): return Map(Obj*).__Enum(2)
            case (Obj is Map):   return Obj.__Enum(2)
            default:             return Obj.OwnProps()
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
}

/**
 * A map containing all valid HTTP methods, mapped to whether they accept a
 * body to be sent.
 * 
 * @return  {Map}
 */
Verbs => (
    M := Map(),
    M.CaseSense := false,
    M.Set("GET",    false,
            "HEAD",   false,
            "OPTIONS",false,
            "TRACE",  false,
            "CONNECT",false,
            "POST",   true,
            "PUT",    true,
            "PATCH",  true,
            "DELETE", true),
    M) ; Verbs
} ; class ApiClient extends WinHttpRequest

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
 * Schema := TypeToken.Of(
 *     Array({
 *         id: Mandatory(Integer),
 *         name: Mandatory(String),
 *         nickname: String
 *     })
 * )
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
        Verb: "Get",
        Path: "/pokemon/" . Ident
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

if (A_LineFile == A_ScriptFullPath) {
    Api      := PokeApi("https://pokeapi.co/api/v2")
    Response := Api.Pokemon["pikachu"]
    Str      := JSON.Dump(Response)

    Keys := ""
    Delim := ", "
    for Key in Response {
        Keys .= Key . Delim
        if (StrLen(Keys) > 60) {
            Keys .= "..." . Delim
            break
        }
    }
    Keys := "{" . SubStr(Keys, 1, -StrLen(Delim)) . "}"

    MsgBox(Format("
        (
        Output: "{}"
        Keys: {}
        )",
        SubStr(Str, 1, 60) . "...",
        Keys
    ), "ApiClient.ahk - TEST #1")
    Keys := ""
}

; {"abilities":[{"ability":{"name":"static","url":"https://pokeapi/ ...""