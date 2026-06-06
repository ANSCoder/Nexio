# NexioExample

iOS demo app for `Nexio` — exercises every public surface of the SDK against live public test APIs (no keys needed).

## Run it

Open `NexioExample.swiftpm` in Xcode (or Swift Playgrounds on iPad) and run on an iOS 16+ simulator/device. It's a Swift Playgrounds App package (`.swiftpm`), so no `.xcodeproj` to maintain — it depends on the parent `Nexio` package via a relative path (`../..`).

iOS only — `NexioImage`'s `Color(.systemGray5)` placeholder doesn't compile on macOS (see Critical Issue #1 in the SDK review), so this target intentionally has no macOS destination.

## Structure

MVVM, one feature per pair of files:

```
AppModule/
├── NexioExampleApp.swift     entry point
├── ContentView.swift         root nav menu, one-time NexioClient setup
├── Models/                   Post, NewPost, Endpoint conformers
├── ViewModels/               @MainActor ObservableObject per screen
├── Views/                    SwiftUI View per screen (XxxView, not XxxScreen)
└── Support/                  DemoSection menu model, StatusBanner,
                              error formatting, custom Interceptors
```

## What's covered

| View | Demonstrates |
|---|---|
| `GetRequestView` | `NexioClient.get(_:)` for arrays and single decodables |
| `CRUDView` | POST / PUT / PATCH / DELETE round-trips |
| `TypedEndpointView` | `Endpoint` protocol + `client.request(_:)` |
| `AuthenticationView` | every `AuthStrategy` case, `AuthInterceptor` dynamic refresh, per-endpoint `Endpoint.auth` override |
| `RetryView` | `RetryInterceptor` against `httpstat.us/503` (retried) vs `/404` (not retried) |
| `ImageGalleryView` | grid loading, prefetch, cache clearing via `ImageLoader` |
| `LoggingView` | custom `Interceptor` impl + actor-backed trace store |
| `ErrorHandlingView` | triggers every `NexioError` case on purpose |

## Test services (no keys)

- `jsonplaceholder.typicode.com` — CRUD sandbox
- `httpstat.us/{code}` — returns whatever HTTP status you ask for
- `picsum.photos` — placeholder images

## Notes for SDK maintainers

Two SDK gaps were worked around here rather than papered over silently:

- **`config.retry` is inert** (`NexioConfig.retry` is stored but never wired to a `RetryInterceptor`) — `ContentView.configureNexio()` registers `RetryInterceptor(policy: .standard)` explicitly, with a `// NOTE:` comment explaining why.
- **`Endpoint.auth: AuthStrategy?` `.none` ambiguity** (`.none` resolves to `Optional.none`/"inherit", not `AuthStrategy.none`/"skip") — `EndpointAuthOverrideEndpoint` uses `.apiKey(...)` instead, with a doc comment spelling out the footgun and the `.some(.none)` workaround.

`Support/Interceptors.swift` also shows the Swift 6–correct way to hand data from a `Sendable` `Interceptor` back to `@MainActor` view models (actor-backed stores) — the SDK's own `AuthTests.CapturingInterceptor` gets this wrong and fails to compile under strict concurrency.
