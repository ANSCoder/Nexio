import Foundation
import Nexio

// MARK: - Type-Safe Endpoints
//
// Grouping requests behind `Endpoint` conformers keeps URL/method/body
// construction out of call sites — see the "Type-Safe Endpoints" demo.

struct PostsEndpoint: Endpoint {
    var baseURL: URL { URL(string: "https://jsonplaceholder.typicode.com")! }
    var path: String { "/posts" }
    var method: HTTPMethod { .get }
    var queryItems: [URLQueryItem] { [URLQueryItem(name: "_limit", value: "10")] }
}

struct PostByIDEndpoint: Endpoint {
    let id: Int
    var baseURL: URL { URL(string: "https://jsonplaceholder.typicode.com")! }
    var path: String { "/posts/\(id)" }
    var method: HTTPMethod { .get }
}

struct CreatePostEndpoint: Endpoint {
    let post: NewPost
    var baseURL: URL { URL(string: "https://jsonplaceholder.typicode.com")! }
    var path: String { "/posts" }
    var method: HTTPMethod { .post }
    var body: (any Encodable)? { post }
}

/// Demonstrates `Endpoint.auth` taking precedence over the client's global
/// `AuthStrategy` — this endpoint always authenticates with its own API key,
/// no matter what `NexioClient.shared.setAuth(_:)` was last called with.
///
/// (Deliberately overrides with a *different strategy* rather than `.none`:
/// `var auth: AuthStrategy? { .none }` is ambiguous — Swift resolves `.none`
/// to `Optional<AuthStrategy>.none`, i.e. "inherit global", not
/// `AuthStrategy.none`/"skip auth". Spell the latter as `.some(.none)` if you
/// genuinely need to opt an endpoint out of auth entirely.)
struct EndpointAuthOverrideEndpoint: Endpoint {
    let id: Int
    var baseURL: URL { URL(string: "https://jsonplaceholder.typicode.com")! }
    var path: String { "/posts/\(id)" }
    var method: HTTPMethod { .get }
    var auth: AuthStrategy? { .apiKey(header: "X-Demo-Override-Key", value: "endpoint-level-secret") }
}
