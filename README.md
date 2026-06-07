<div align="center">

![Nexio](https://raw.githubusercontent.com/ANSCoder/Nexio/main/Resources/NexioBanner.png)

**Lightweight, actor-based Swift networking SDK**

[![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2016%20·%20macOS%2013%20·%20watchOS%209%20·%20tvOS%2016-blue.svg)](https://developer.apple.com)
[![SPM](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://swift.org/package-manager)
[![License](https://img.shields.io/badge/License-MIT-lightgrey.svg)](LICENSE)
[![CI](https://github.com/ANSCoder/Nexio/actions/workflows/ci.yml/badge.svg)](https://github.com/ANSCoder/Nexio/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/ANSCoder/Nexio/branch/main/graph/badge.svg)](https://codecov.io/gh/ANSCoder/Nexio)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FANSCoder%2FNexio%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/ANSCoder/Nexio)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FANSCoder%2FNexio%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/ANSCoder/Nexio)

Typed JSON requests · Auth strategies · Retry with backoff · Interceptor pipeline · SwiftUI image loading · Zero dependencies

</div>

---

## Features

- **Actor-based** — `NexioClient` is a Swift actor; zero data-race risk, safe to call from any concurrency context
- **Typed requests** — `get`, `post`, `put`, `patch`, `delete` return decoded `Decodable` values directly
- **Type-safe endpoints** — `Endpoint` protocol for grouping request details in reusable structs
- **Auth strategies** — bearer token, API key, custom headers, or dynamic provider (OAuth refresh)
- **Interceptor pipeline** — adapt requests and retry failures with full control
- **Retry with backoff** — none, linear, or exponential backoff; configurable per policy
- **SwiftUI image loading** — `NexioImage` drop-in for `AsyncImage` with `URLCache`-backed caching and prefetch
- **Structured errors** — `NexioError` covers network, auth, 4xx/5xx, and decoding failures
- **Zero dependencies** — pure Swift, built on `URLSession`

---

## Installation

### Swift Package Manager

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/ANSCoder/Nexio", from: "1.0.0")
],
targets: [
    .target(name: "YourApp", dependencies: [
        .product(name: "Nexio", package: "Nexio")
    ])
]
```

Or add it in Xcode: **File → Add Package Dependencies**, paste the repo URL.

---

## Quick Start

### Configure once at app launch

```swift
// AppDelegate / App.init
var config = NexioConfig()
config.baseURL    = URL(string: "https://api.example.com")
config.timeout    = 15
config.retry      = .standard   // 3 attempts, exponential backoff
config.logLevel   = .errors
await NexioClient.shared.configure(config)
await NexioClient.shared.setAuth(.bearer("your-token"))
```

### Make typed requests

```swift
// GET — decodes JSON automatically
let users: [User] = try await NexioClient.shared.get("/users")

// POST with body
let body = CreateUserRequest(name: "Alice")
let created: User = try await NexioClient.shared.post("/users", body: body)

// PUT / PATCH / DELETE
let updated: User = try await NexioClient.shared.put("/users/42", body: changes)
try await NexioClient.shared.delete("/users/42")

// Absolute URLs work too (ignores baseURL)
let user: User = try await NexioClient.shared.get("https://api.example.com/users/1")
```

### Top-level shortcuts

```swift
// Shorthand for NexioClient.shared.get / .post
let users: [User] = try await nexioGet("/users")
let created: User = try await nexioPost("/users", body: newUser)
```

---

## Authentication

```swift
// Static bearer token
await NexioClient.shared.setAuth(.bearer("jwt-token"))

// API key in a custom header
await NexioClient.shared.setAuth(.apiKey(header: "X-Api-Key", value: "secret"))

// Arbitrary headers
await NexioClient.shared.setAuth(.custom(["X-Tenant-ID": "acme", "X-Version": "2"]))

// Dynamic token — closure called before every request (ideal for OAuth refresh)
let authInterceptor = AuthInterceptor {
    await TokenStore.shared.currentToken()   // returns AuthStrategy
}
await NexioClient.shared.addInterceptor(authInterceptor)
```

### Per-endpoint auth override

```swift
struct PublicEndpoint: Endpoint {
    var baseURL: URL  { URL(string: "https://api.example.com")! }
    var path: String  { "/status" }
    var method: HTTPMethod { .get }
    var auth: AuthStrategy? { .some(.none) }  // skip global auth for this request
}
```

---

## Type-Safe Endpoints

Group URL, method, query params, headers, and body in one reusable struct:

```swift
struct GetUser: Endpoint {
    let id: Int
    var baseURL: URL      { URL(string: "https://api.example.com")! }
    var path: String      { "/users/\(id)" }
    var method: HTTPMethod { .get }
}

struct SearchUsers: Endpoint {
    let query: String
    var baseURL: URL      { URL(string: "https://api.example.com")! }
    var path: String      { "/users/search" }
    var method: HTTPMethod { .get }
    var queryItems: [URLQueryItem] { [URLQueryItem(name: "q", value: query)] }
}

let user: User          = try await NexioClient.shared.request(GetUser(id: 42))
let results: [User]     = try await NexioClient.shared.request(SearchUsers(query: "alice"))
```

---

## Retry

```swift
// Via config (recommended — applied automatically)
config.retry = .standard                                   // 3 retries, exponential backoff
config.retry = RetryPolicy(maxAttempts: 5,
                           backoff: .linear(seconds: 2))   // custom

// Via interceptor (for per-client or programmatic control)
await NexioClient.shared.addInterceptor(
    RetryInterceptor(policy: .standard)
)
```

**Retried automatically on:** `.noInternet`, `.timeout`, and 5xx `serverError`.  
**Not retried:** 4xx errors (client errors are not transient).

---

## Interceptors

Implement `Interceptor` to hook into every request:

```swift
struct LoggingInterceptor: Interceptor {
    func adapt(_ request: URLRequest, for session: URLSession) async throws -> URLRequest {
        print("→ \(request.httpMethod ?? "") \(request.url?.absoluteString ?? "")")
        return request
    }
    func retry(_ request: URLRequest, dueTo error: NexioError, attempt: Int) async -> Bool {
        false
    }
}

await NexioClient.shared.addInterceptor(LoggingInterceptor())
```

Interceptors run in **insertion order** during `adapt`, and **reverse order** during `retry`.

---

## Error Handling

All errors are typed as `NexioError`:

```swift
do {
    let user: User = try await NexioClient.shared.get("/users/1")
} catch NexioError.unauthorized {
    // Redirect to login
} catch NexioError.notFound {
    // Show 404 UI
} catch NexioError.noInternet {
    // Show offline banner
} catch NexioError.serverError(let statusCode, let data) {
    // Handle 5xx
} catch NexioError.decodingFailed(let underlying, let data) {
    // Log raw response for debugging
    print(String(data: data, encoding: .utf8) ?? "")
} catch NexioError.invalidURL(let string) {
    // Bad URL at call site
}
```

---

## Image Loading (SwiftUI)

`NexioImage` is a drop-in replacement for `AsyncImage` with transparent `URLCache` caching (50 MB memory / 200 MB disk by default):

```swift
// Default — gray placeholder, photo icon on failure
NexioImage("https://cdn.example.com/photo.jpg")
    .frame(width: 100, height: 100)
    .clipShape(Circle())

// Custom placeholder and failure views
NexioImage(
    "https://cdn.example.com/photo.jpg",
    placeholder:  { ProgressView() },
    failureImage: { Image(systemName: "person.crop.circle.fill") }
)

// Prefetch a list for smoother scroll performance
let urls = items.compactMap { URL(string: $0.imageURL) }
await ImageLoader.shared.prefetch(urls)

// Clear cache
await ImageLoader.shared.clearCache()
```

---

## Concurrency

`NexioClient` is a Swift actor — all state mutations are serialized automatically with no extra effort. In-flight network I/O runs concurrently through `URLSession`'s connection pool:

```swift
// Three requests in flight simultaneously
async let users:    [User]    = NexioClient.shared.get("/users")
async let posts:    [Post]    = NexioClient.shared.get("/posts")
async let comments: [Comment] = NexioClient.shared.get("/comments")

let (u, p, c) = try await (users, posts, comments)
```

Actor isolation serializes only the microsecond-scale bookkeeping (building requests, applying headers, decoding JSON). Network round-trips never block other callers.

---

## Testing

Inject a custom `URLProtocol` subclass via `NexioConfig.protocolClasses` to stub responses without hitting the network:

```swift
var config = NexioConfig()
config.protocolClasses = [MockURLProtocol.self]
await client.configure(config)
```

---

## Requirements

| Platform | Minimum |
|----------|---------|
| iOS      | 16.0    |
| macOS    | 13.0    |
| watchOS  | 9.0     |
| tvOS     | 16.0    |

**Swift 6.2+** · Zero external dependencies

---

## License

Nexio is released under the MIT license. See [LICENSE](LICENSE) for details.
