# Changelog

All notable changes to Nexio will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Nexio uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

No public signatures changed. The entries below are behavior fixes and internal changes.

### Fixed
- HTTP 5xx and 429 responses are now retried when a retry policy is configured. Previously they were never retried.
- Per-endpoint `auth` is no longer overwritten by a registered `AuthInterceptor`. `.some(.none)` sends no token.
- Calling a refresh endpoint from inside an `AuthInterceptor` provider no longer re-enters the same provider.
- POST and PATCH are no longer retried by default. Only idempotent methods retry.
- Cancelling a request stops retries and throws `CancellationError`, instead of retrying or reporting a failure.
- `NexioImage` no longer shows the failure image when a load is cancelled because the view moved on.
- `RetryPolicy` backoff is capped at 60 seconds, which prevents an integer overflow trap on large exponential delays.
- `configure(_:)` can now disable retry. Previously the retry setting stuck once enabled.
- `configure(_:)` invalidates the previous `URLSession` instead of leaking it.
- Retry is capped at 10 retries per request, so a custom interceptor can't retry indefinitely.

### Changed
- `NexioConfig.retry` is now held by the client and applied inside the request pipeline. It no longer inserts a `RetryInterceptor` into the interceptor list.
- JSON decoding happens off the `NexioClient` actor.
- Image decoding in `ImageLoader` happens off the actor.
- `ImageLoader.prefetch(_:)` fetches at most 4 images at a time.
- `URLError.cancelled` surfaces as `CancellationError`, not `NexioError.unknown`.

## [1.0.0] - 2026-06-07

### Added
- `NexioClient` actor — type-safe GET, POST, PUT, PATCH, DELETE with automatic JSON encoding/decoding
- `NexioConfig` — base URL, timeout, default headers, retry policy, log level
- `Endpoint` protocol — type-safe request descriptors with per-request auth override
- `AuthStrategy` — bearer token, API key, custom headers, or `.none` to skip auth
- `AuthInterceptor` — dynamic auth provider (async closure, for OAuth token refresh)
- `Interceptor` protocol — adapt requests and retry failures with full pipeline control
- `RetryInterceptor` + `RetryPolicy` — none, linear, or exponential backoff; standard preset
- `NexioConfig.retry` auto-installs `RetryInterceptor` on `configure(_:)`
- `NexioConfig.protocolClasses` — inject `URLProtocol` subclasses for testing
- `ImageLoader` actor — `URLCache`-backed remote image loading with prefetch and cache clear
- `NexioImage` SwiftUI view — drop-in `AsyncImage` replacement with caching, placeholder, failure view, transition
- `NexioError` — typed errors: `invalidURL`, `noInternet`, `timeout`, `unauthorized`, `notFound`, `serverError`, `decodingFailed`, `unknown`
- Top-level `nexioGet` / `nexioPost` convenience functions over `NexioClient.shared`
- Swift 6 strict concurrency compliance — zero data-race warnings
- MIT license, license headers on all source files
