import Foundation
import Nexio

// MARK: - Shared capture stores
//
// Both stores are actors: that's the Swift-concurrency-correct way to let a
// `Sendable` `Interceptor` (which may run on any executor) hand data back to
// `@MainActor` view models without ever capturing/mutating a local `var` from
// inside a `@Sendable` closure (a pattern that fails to compile under Swift 6
// strict concurrency — see the SDK's own AuthTests for that exact mistake).

actor RequestLogStore {
    static let shared = RequestLogStore()

    private(set) var entries: [String] = []

    func record(_ entry: String) {
        entries.append(entry)
        if entries.count > 200 {
            entries.removeFirst(entries.count - 200)
        }
    }

    func clear() {
        entries.removeAll()
    }
}

actor LastRequestHeadersStore {
    static let shared = LastRequestHeadersStore()

    private(set) var headers: [String: String] = [:]

    func record(_ headers: [String: String]) {
        self.headers = headers
    }
}

// MARK: - Custom Interceptors
//
// Demonstrates implementing `Interceptor` yourself — the same seam Nexio uses
// internally for `AuthInterceptor` and `RetryInterceptor`.

/// Mirrors `NexioConfig.logLevel == .all` but writes to an observable store so
/// the "Interceptors & Logging" screen can render the trace in the UI instead
/// of the Xcode console.
struct ConsoleLogInterceptor: Interceptor {

    func adapt(_ request: URLRequest, for session: URLSession) async throws -> URLRequest {
        let line = "→ \(request.httpMethod ?? "?") \(request.url?.absoluteString ?? "")"
        await RequestLogStore.shared.record(line)
        return request
    }

    func retry(_ request: URLRequest, dueTo error: NexioError, attempt: Int) async -> Bool {
        let line = "↻ retry #\(attempt + 1) — \(error.errorDescription ?? "\(error)")"
        await RequestLogStore.shared.record(line)
        return false // logging only; RetryInterceptor owns the actual decision
    }
}

/// Records the fully-adapted outgoing headers so the Authentication screen can
/// show exactly what `AuthStrategy`/`AuthInterceptor`/`Endpoint.auth` produced
/// on the wire — the same idea as the SDK's test-only `CapturingInterceptor`,
/// but actor-backed instead of capturing a mutable local in a closure.
struct HeaderCaptureInterceptor: Interceptor {

    func adapt(_ request: URLRequest, for session: URLSession) async throws -> URLRequest {
        await LastRequestHeadersStore.shared.record(request.allHTTPHeaderFields ?? [:])
        return request
    }

    func retry(_ request: URLRequest, dueTo error: NexioError, attempt: Int) async -> Bool {
        false
    }
}
