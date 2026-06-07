# Changelog

All notable changes to Nexio will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Nexio uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

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
