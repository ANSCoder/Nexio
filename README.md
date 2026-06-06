# Nexio

A lightweight, actor-based Swift networking SDK — typed requests, auth, retry, interceptors, and SwiftUI image loading in one zero-dependency package.

**Pure Swift 6.2 · Actor-based · Zero dependencies · iOS 16+ · macOS 13+**

---

## Install

```swift
// Package.swift
.package(url: "https://github.com/ANSCoder/Nexio", from: "1.0.0")

// Target dependency
.product(name: "Nexio", package: "Nexio")
```

---

## Quick Start

### JSON requests

```swift
// GET
let users: [User] = try await Nexio.shared.get("https://api.example.com/users")

// POST
let newUser = CreateUserRequest(name: "Alice")
let created: User = try await Nexio.shared.post("https://api.example.com/users", body: newUser)

// Top-level shortcuts
let users: [User] = try await nexioGet("https://api.example.com/users")
```

### One-time configuration (app launch)

```swift
var config = NexioConfig()
config.baseURL = URL(string: "https://api.example.com")
config.timeout = 15
config.retry = .standard        // 3 attempts, exponential backoff
config.logLevel = .errors
await Nexio.shared.configure(config)
```

---

## Authentication

```swift
// Bearer token (most common)
await Nexio.shared.setAuth(.bearer("your-jwt-token"))

// API key header
await Nexio.shared.setAuth(.apiKey(header: "X-Api-Key", value: "secret"))

// Dynamic token (OAuth refresh, etc.)
let interceptor = AuthInterceptor {
    await TokenStore.shared.currentToken()  // called before every request
}
await Nexio.shared.addInterceptor(interceptor)
```

---

## Type-Safe Endpoints

```swift
struct GetUser: Endpoint {
    let id: Int
    var baseURL: URL { URL(string: "https://api.example.com")! }
    var path: String { "/users/\(id)" }
    var method: HTTPMethod { .get }
    // Override auth for this endpoint only:
    var auth: AuthStrategy? { .none }
}

let user: User = try await Nexio.shared.request(GetUser(id: 42))
```

---

## Retry

```swift
// Global retry via config
config.retry = .standard          // 3 retries, exponential backoff

// Or add the interceptor directly for more control
let retry = RetryInterceptor(policy: RetryPolicy(maxAttempts: 5, backoff: .linear(seconds: 2)))
await Nexio.shared.addInterceptor(retry)
```

Retried automatically on: `.noInternet`, `.timeout`, and 5xx server errors.

---

## Image Loading (SwiftUI)

```swift
// Drop-in AsyncImage replacement — cached automatically
NexioImage("https://cdn.example.com/photo.jpg")
    .frame(width: 100, height: 100)
    .clipShape(Circle())

// Custom placeholder and failure views
NexioImage(
    "https://cdn.example.com/photo.jpg",
    placeholder: { ProgressView() },
    failureImage: { Image(systemName: "person.crop.circle") }
)

// Prefetch for smoother scroll performance
await ImageLoader.shared.prefetch(imageURLs)
```

---

## Concurrency

`NexioClient` is an actor — call it from anywhere, as many times as you like, in parallel. There's no internal request queue or call cap:

```swift
async let users    : [User]    = Nexio.shared.get("/users")
async let posts    : [Post]    = Nexio.shared.get("/posts")
async let comments : [Comment] = Nexio.shared.get("/comments")

let (u, p, c) = try await (users, posts, comments)   // all three in flight together
```

Each call suspends on its network round-trip and releases the actor, so in-flight requests run their wire I/O concurrently through `URLSession`'s own connection pool — actor isolation only ever serializes the microsecond-scale bookkeeping (building the request, applying auth/headers, encoding/decoding JSON), never the network wait.

The practical ceiling on *simultaneous* requests comes from the OS network stack, not Nexio: `URLSessionConfiguration.httpMaximumConnectionsPerHost` (a handful of TCP connections per host on HTTP/1.1; HTTP/2 multiplexes far more requests over fewer connections). That's the same limit every `URLSession`-based client — Alamofire included — runs into; Nexio doesn't add one of its own.

---

## Error Handling

```swift
do {
    let user: User = try await Nexio.shared.get("/users/1")
} catch NexioError.unauthorized {
    // redirect to login
} catch NexioError.noInternet {
    // show offline banner
} catch NexioError.decodingFailed(let underlying, let data) {
    // log decoding error + raw response
} catch {
    // NexioError.unknown
}
```

---

## Requirements

| Platform | Minimum |
|----------|---------|
| iOS      | 16.0    |
| macOS    | 13.0    |
| watchOS  | 9.0     |
| tvOS     | 16.0    |

Swift 6.2+, zero external dependencies.

---

## License

MIT — see [LICENSE](LICENSE).
