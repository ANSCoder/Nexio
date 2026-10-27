// Copyright (c) 2026 ANSCoder
// Licensed under the MIT License. See LICENSE in the project root for details.

import Foundation
import os

// MARK: - NexioClient

private let logger = Logger(subsystem: "com.nexio", category: "network")

/// The main entry point for Nexio networking.
///
/// `NexioClient` is a Swift actor. Configuration changes and request bookkeeping
/// are serialised by the actor; network I/O and JSON decoding run outside it,
/// so a large response never blocks other requests.
///
/// **Quick start**
/// ```swift
/// // One-time setup (e.g. app launch)
/// await NexioClient.shared.configure(NexioConfig())
/// await NexioClient.shared.setAuth(.bearer("my-token"))
///
/// // Make a typed request
/// let users: [User] = try await NexioClient.shared.get("https://api.example.com/users")
/// ```
public actor NexioClient {

    // MARK: - Singleton

    /// Shared instance. Configure it once at app launch, then use anywhere.
    public static let shared = NexioClient()

    // MARK: - Constants

    /// Hard ceiling on attempts per request, independent of any interceptor.
    /// Stops a custom interceptor that always returns `true` from retrying forever.
    private static let attemptCeiling = 10

    // MARK: - Private State

    private var config: NexioConfig = NexioConfig()
    private var authStrategy: AuthStrategy = .none
    private var retryPolicy: RetryPolicy = .none
    private var interceptors: [any Interceptor] = []
    private var session: URLSession = URLSession.shared
    private let encoder: JSONEncoder = JSONEncoder()

    // MARK: - Init

    /// Creates a standalone client. Use ``shared`` for typical app usage.
    public init() {}

    // MARK: - Configuration

    /// Applies a new configuration. Rebuilds the underlying `URLSession`.
    ///
    /// Requests already in flight finish on the previous session, which is then
    /// invalidated. Retry settings are applied from this point on.
    ///
    /// - Parameter config: The configuration to apply.
    public func configure(_ config: NexioConfig) {
        self.config = config
        let previous = session

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = config.timeout
        // Default headers are applied per request (see applyDefaultHeaders), not
        // at session level. Session-level headers would bypass no-auth overrides.
        if let protocolClasses = config.protocolClasses {
            sessionConfig.protocolClasses = protocolClasses + (sessionConfig.protocolClasses ?? [])
        }
        session = URLSession(configuration: sessionConfig)

        // Release the session we replaced. Tasks already running are allowed to finish.
        if previous !== URLSession.shared {
            previous.finishTasksAndInvalidate()
        }

        // Retry is client state rather than an interceptor, so reconfiguring can
        // always change or disable it.
        retryPolicy = config.retry
    }

    /// Sets the global authentication strategy.
    ///
    /// Individual ``Endpoint`` conformers can override this per-request via
    /// ``Endpoint/auth``.
    ///
    /// - Parameter strategy: The auth strategy to apply globally.
    public func setAuth(_ strategy: AuthStrategy) {
        authStrategy = strategy
    }

    /// Registers an ``Interceptor`` that runs on every request.
    ///
    /// Interceptors are applied in insertion order during `adapt`, and in
    /// reverse insertion order during `retry`.
    ///
    /// - Parameter interceptor: The interceptor to add.
    public func addInterceptor(_ interceptor: any Interceptor) {
        interceptors.append(interceptor)
    }

    // MARK: - JSON Requests

    /// Performs a GET request and decodes the JSON response.
    ///
    /// - Parameters:
    ///   - url: Absolute URL string, or a path appended to ``NexioConfig/baseURL``.
    ///   - headers: Extra headers merged with ``NexioConfig/defaultHeaders``.
    /// - Returns: Decoded value of type `T`.
    /// - Throws: ``NexioError``
    public func get<T: Decodable & Sendable>(
        _ url: String,
        headers: [String: String] = [:]
    ) async throws -> T {
        let request = try buildRequest(url: url, method: .get, headers: headers, body: nil as String?)
        return try await perform(request, skipDynamicAuth: false)
    }

    /// Performs a POST request, encoding `body` as JSON, and decodes the response.
    ///
    /// POST is not retried by default, because repeating it can duplicate work
    /// on the server.
    ///
    /// - Parameters:
    ///   - url: Absolute URL string, or a path appended to ``NexioConfig/baseURL``.
    ///   - body: JSON-encodable request body.
    ///   - headers: Extra headers.
    /// - Returns: Decoded value of type `T`.
    /// - Throws: ``NexioError``
    public func post<T: Decodable & Sendable>(
        _ url: String,
        body: some Encodable & Sendable,
        headers: [String: String] = [:]
    ) async throws -> T {
        let request = try buildRequest(url: url, method: .post, headers: headers, body: body)
        return try await perform(request, skipDynamicAuth: false)
    }

    /// Performs a PUT request, encoding `body` as JSON, and decodes the response.
    ///
    /// - Parameters:
    ///   - url: Absolute URL string, or a path appended to ``NexioConfig/baseURL``.
    ///   - body: JSON-encodable request body.
    ///   - headers: Extra headers merged with ``NexioConfig/defaultHeaders``.
    /// - Returns: Decoded value of type `T`.
    /// - Throws: ``NexioError``
    public func put<T: Decodable & Sendable>(
        _ url: String,
        body: some Encodable & Sendable,
        headers: [String: String] = [:]
    ) async throws -> T {
        let request = try buildRequest(url: url, method: .put, headers: headers, body: body)
        return try await perform(request, skipDynamicAuth: false)
    }

    /// Performs a PATCH request, encoding `body` as JSON, and decodes the response.
    ///
    /// PATCH is not retried by default, for the same reason as POST.
    ///
    /// - Parameters:
    ///   - url: Absolute URL string, or a path appended to ``NexioConfig/baseURL``.
    ///   - body: JSON-encodable request body.
    ///   - headers: Extra headers merged with ``NexioConfig/defaultHeaders``.
    /// - Returns: Decoded value of type `T`.
    /// - Throws: ``NexioError``
    public func patch<T: Decodable & Sendable>(
        _ url: String,
        body: some Encodable & Sendable,
        headers: [String: String] = [:]
    ) async throws -> T {
        let request = try buildRequest(url: url, method: .patch, headers: headers, body: body)
        return try await perform(request, skipDynamicAuth: false)
    }

    /// Performs a DELETE request. Does not decode a response body.
    ///
    /// - Parameters:
    ///   - url: Absolute URL string, or a path appended to ``NexioConfig/baseURL``.
    ///   - headers: Extra headers.
    /// - Throws: ``NexioError``
    public func delete(
        _ url: String,
        headers: [String: String] = [:]
    ) async throws {
        let request = try buildRequest(url: url, method: .delete, headers: headers, body: nil as String?)
        let (data, http) = try await send(request, skipDynamicAuth: false)
        logIfNeeded(request: request, response: http, data: data)
        if let error = http.nexioError(data: data) {
            throw error
        }
    }

    // MARK: - Typed Endpoint

    /// Performs a request described by a typed ``Endpoint`` conformer and decodes
    /// the JSON response.
    ///
    /// If the endpoint sets ``Endpoint/auth``, that strategy is used for this
    /// request and any registered ``AuthInterceptor`` is skipped.
    ///
    /// ```swift
    /// let user: User = try await NexioClient.shared.request(GetUserEndpoint(id: 42))
    /// ```
    ///
    /// - Parameter endpoint: The endpoint to execute.
    /// - Returns: Decoded value of type `T`.
    /// - Throws: ``NexioError``
    public func request<T: Decodable & Sendable>(_ endpoint: some Endpoint) async throws -> T {
        let urlRequest = try buildRequest(from: endpoint)
        return try await perform(urlRequest, skipDynamicAuth: endpoint.auth != nil)
    }

    // MARK: - Raw Data

    /// Fetches raw `Data` from a URL. Used internally by ``ImageLoader``.
    ///
    /// - Parameter url: Absolute URL string.
    /// - Returns: Raw response bytes.
    /// - Throws: ``NexioError``
    public func data(from url: String) async throws -> Data {
        guard let resolvedURL = resolve(url) else {
            throw NexioError.invalidURL(url)
        }
        var request = URLRequest(url: resolvedURL)
        request.httpMethod = HTTPMethod.get.rawValue
        applyDefaultHeaders(to: &request)
        applyAuth(authStrategy, to: &request)
        let (data, http) = try await send(request, skipDynamicAuth: false)
        logIfNeeded(request: request, response: http, data: data)
        if let error = http.nexioError(data: data) { throw error }
        return data
    }

    // MARK: - Private Helpers

    /// Sends a built request and decodes a successful response body as `T`.
    ///
    /// Decoding runs off the actor, so a large payload doesn't hold up other callers.
    ///
    /// - Parameters:
    ///   - request: The fully built request.
    ///   - skipDynamicAuth: `true` when the request carries its own auth.
    /// - Returns: The decoded response body.
    /// - Throws: ``NexioError/decodingFailed(underlying:data:)`` if `T` doesn't
    ///   match the response, or any status-mapped ``NexioError``.
    private func perform<T: Decodable & Sendable>(
        _ request: URLRequest,
        skipDynamicAuth: Bool
    ) async throws -> T {
        let (data, http) = try await send(request, skipDynamicAuth: skipDynamicAuth)
        logIfNeeded(request: request, response: http, data: data)
        if let error = http.nexioError(data: data) { throw error }
        return try await NexioDecoding.decode(T.self, from: data)
    }

    /// Runs a request through the adapt → send → retry pipeline.
    ///
    /// Each attempt re-runs the full adapter chain, so a token-refreshing
    /// ``AuthInterceptor`` mints a fresh credential per attempt.
    ///
    /// Status failures (5xx, 429) and transport failures are both retry
    /// candidates. When the pipeline stops retrying, the last response is
    /// returned so the caller can map it to a ``NexioError``.
    ///
    /// - Parameters:
    ///   - original: The request before adaptation.
    ///   - skipDynamicAuth: Skip ``AuthInterceptor`` for this request.
    /// - Returns: Raw response data and the parsed `HTTPURLResponse`.
    /// - Throws: `CancellationError` if the task was cancelled, otherwise the
    ///   transport ``NexioError`` from the final attempt.
    private func send(
        _ original: URLRequest,
        skipDynamicAuth: Bool
    ) async throws -> (Data, HTTPURLResponse) {
        // A token refresh issued from inside an AuthInterceptor provider must not
        // go through that same interceptor again, or it would recurse.
        let skipAuth = skipDynamicAuth || AuthResolution.isResolving
        var attempt = 0

        while true {
            try Task.checkCancellation()
            let adapted = try await adapt(original, skipDynamicAuth: skipAuth)

            do {
                let (data, http) = try await session.nexioData(for: adapted)
                if let statusError = http.nexioError(data: data) {
                    if await shouldRetry(adapted, dueTo: statusError, attempt: attempt) {
                        attempt += 1
                        continue
                    }
                    // A retry delay or interceptor may have observed cancellation
                    // and declined the retry. Preserve cancellation instead of
                    // returning the last HTTP error response.
                    try Task.checkCancellation()
                }
                return (data, http)
            } catch let error as NexioError {
                if await shouldRetry(adapted, dueTo: error, attempt: attempt) {
                    attempt += 1
                    continue
                }
                if Task.isCancelled { throw CancellationError() }
                throw error
            }
        }
    }

    /// Runs every interceptor's `adapt` in insertion order.
    ///
    /// ``AuthInterceptor`` is skipped when the request carries its own auth.
    ///
    /// - Parameters:
    ///   - request: The request to adapt.
    ///   - skipDynamicAuth: Whether to skip ``AuthInterceptor``.
    /// - Returns: The adapted request.
    private func adapt(_ request: URLRequest, skipDynamicAuth: Bool) async throws -> URLRequest {
        var adapted = request
        for interceptor in interceptors {
            if skipDynamicAuth, interceptor is AuthInterceptor { continue }
            adapted = try await interceptor.adapt(adapted, for: session)
        }
        return adapted
    }

    /// Decides whether a failed attempt should be retried.
    ///
    /// The client's configured ``NexioConfig/retry`` policy is consulted first,
    /// then registered interceptors in reverse order. The first to return `true`
    /// wins. Retries stop at `attemptCeiling` no matter what.
    ///
    /// - Parameters:
    ///   - request: The adapted request that failed.
    ///   - error: The failure to evaluate.
    ///   - attempt: Zero-based attempt counter.
    /// - Returns: `true` to run another attempt.
    private func shouldRetry(
        _ request: URLRequest,
        dueTo error: NexioError,
        attempt: Int
    ) async -> Bool {
        guard !Task.isCancelled, attempt < Self.attemptCeiling else { return false }
        if await retryPolicy.shouldRetry(request, dueTo: error, attempt: attempt) {
            return true
        }
        for interceptor in interceptors.reversed() {
            if await interceptor.retry(request, dueTo: error, attempt: attempt) {
                return true
            }
        }
        return false
    }

    /// Builds a `URLRequest` for a string-URL call: resolves `url` against
    /// ``NexioConfig/baseURL``, merges default and extra headers, applies
    /// the global auth strategy, and JSON-encodes `body` if present.
    ///
    /// - Parameters:
    ///   - url: Absolute URL string, or a path appended to ``NexioConfig/baseURL``.
    ///   - method: The HTTP method to use.
    ///   - headers: Extra headers layered on top of ``NexioConfig/defaultHeaders``.
    ///   - body: Optional JSON-encodable request body.
    /// - Returns: A populated `URLRequest`, ready for the interceptor pipeline.
    /// - Throws: ``NexioError/invalidURL(_:)`` if `url` can't be resolved.
    private func buildRequest<Body: Encodable & Sendable>(
        url: String,
        method: HTTPMethod,
        headers: [String: String],
        body: Body?
    ) throws -> URLRequest {
        guard let resolved = resolve(url) else {
            throw NexioError.invalidURL(url)
        }
        var request = URLRequest(url: resolved)
        request.httpMethod = method.rawValue
        applyDefaultHeaders(to: &request)
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        applyAuth(authStrategy, to: &request)
        if let body {
            request.httpBody = try encoder.encode(body)
        }
        return request
    }

    /// Builds a `URLRequest` from a typed ``Endpoint``: composes `baseURL` +
    /// `path` + query items, merges headers, resolves per-endpoint vs. global
    /// auth, and JSON-encodes the endpoint's body if present.
    ///
    /// - Note: ``Endpoint/auth`` wins over the client's global auth strategy
    ///   whenever it's non-`nil`. See ``Endpoint/auth`` for the `AuthStrategy?`
    ///   semantics, including the `.some(.none)` vs `nil` distinction.
    ///
    /// - Parameter endpoint: The endpoint describing the request.
    /// - Returns: A populated `URLRequest`, ready for the interceptor pipeline.
    /// - Throws: ``NexioError/invalidURL(_:)`` if the composed URL is malformed.
    private func buildRequest(from endpoint: some Endpoint) throws -> URLRequest {
        var components = URLComponents(
            url: endpoint.baseURL.appendingPathComponent(endpoint.path),
            resolvingAgainstBaseURL: false
        )
        if !endpoint.queryItems.isEmpty {
            components?.queryItems = endpoint.queryItems
        }
        guard let url = components?.url else {
            throw NexioError.invalidURL(endpoint.baseURL.absoluteString + endpoint.path)
        }
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        applyDefaultHeaders(to: &request)
        endpoint.headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        // Per-request auth takes precedence over global auth
        if case .some(.none) = endpoint.auth {
            // Explicit no-auth: remove credentials that defaults or endpoint headers
            // may have added, and prevent URLSession from adding stored cookies.
            stripCredentialHeaders(from: &request)
            request.httpShouldHandleCookies = false
        } else {
            let effectiveAuth = endpoint.auth ?? authStrategy
            applyAuth(effectiveAuth, to: &request)
        }

        if let body = endpoint.body {
            request.httpBody = try encoder.encode(body)
        }
        return request
    }

    /// Resolves a user-supplied string to an absolute `URL`.
    ///
    /// Strings that already parse with a scheme (e.g. `"https://..."`) pass
    /// through unchanged. Anything else is treated as a path and appended to
    /// ``NexioConfig/baseURL``. Returns `nil`, surfaced by callers as
    /// ``NexioError/invalidURL(_:)``, when neither applies.
    ///
    /// - Parameter urlString: Absolute URL string, or a relative path.
    /// - Returns: The resolved `URL`, or `nil` if it can't be resolved.
    private func resolve(_ urlString: String) -> URL? {
        if let absolute = URL(string: urlString), absolute.scheme != nil {
            return absolute
        }
        guard let baseURL = config.baseURL,
              let relativeComponents = URLComponents(string: urlString) else {
            return nil
        }

        // Treat a relative URL's query and fragment as URL components, not as
        // part of the path passed to `appendingPathComponent` (`?` is escaped
        // there, turning `/posts?_limit=10` into `/posts%3F_limit=10`).
        let pathURL = baseURL.appendingPathComponent(relativeComponents.path)
        guard var resolvedComponents = URLComponents(url: pathURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        resolvedComponents.queryItems = relativeComponents.queryItems
        resolvedComponents.fragment = relativeComponents.fragment
        return resolvedComponents.url
    }

    /// Merges ``NexioConfig/defaultHeaders`` onto `request`, overwriting any
    /// existing values for the same field names.
    ///
    /// - Parameter request: The request to mutate in place.
    private func applyDefaultHeaders(to request: inout URLRequest) {
        config.defaultHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }
    }

    /// Header names treated as credentials. Removed for explicit no-auth requests.
    private static let credentialHeaderNames = [
        "Authorization", "Proxy-Authorization", "X-Api-Key", "Cookie"
    ]

    /// Removes credential headers from `request`, whatever added them.
    ///
    /// - Parameter request: The request to clean, in place.
    private func stripCredentialHeaders(from request: inout URLRequest) {
        for name in Self.credentialHeaderNames {
            request.setValue(nil, forHTTPHeaderField: name)
        }
    }

    /// Applies an ``AuthStrategy`` to `request` by setting the appropriate
    /// header(s). `.none` is a deliberate no-op.
    ///
    /// - Parameters:
    ///   - strategy: The strategy to apply, global or per-endpoint.
    ///   - request: The request to mutate in place.
    private func applyAuth(_ strategy: AuthStrategy, to request: inout URLRequest) {
        switch strategy {
        case .bearer(let token):
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        case .apiKey(let header, let value):
            request.setValue(value, forHTTPHeaderField: header)
        case .custom(let headers):
            headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        case .none:
            break
        }
    }

    /// Prints a request/response trace to the console per ``NexioConfig/logLevel``:
    /// silent for `.none`, failures only for `.errors`, full request and response
    /// lines for `.all`.
    ///
    /// - Parameters:
    ///   - request: The request that was sent.
    ///   - response: The response that came back.
    ///   - data: The raw response body (only its byte count is logged).
    private func logIfNeeded(request: URLRequest, response: HTTPURLResponse, data: Data) {
        switch config.logLevel {
        case .none:
            break
        case .errors:
            guard !response.isSuccess else { return }
            logger.error("\(request.httpMethod ?? "?") \(URLRedactor.redacted(request.url)) -> \(response.statusCode)")
        case .all:
            logger.info("\(request.httpMethod ?? "?") \(URLRedactor.redacted(request.url)) -> \(response.statusCode) (\(data.count) bytes)")
        }
    }
}

// MARK: - Top-Level Convenience

/// Performs a GET request via ``NexioClient/shared`` and decodes the JSON response.
///
/// ```swift
/// let users: [User] = try await nexioGet("https://api.example.com/users")
/// ```
public func nexioGet<T: Decodable & Sendable>(_ url: String) async throws -> T {
    try await NexioClient.shared.get(url)
}

/// Performs a POST request via ``NexioClient/shared`` and decodes the JSON response.
///
/// ```swift
/// let created: User = try await nexioPost("https://api.example.com/users", body: newUser)
/// ```
public func nexioPost<T: Decodable & Sendable>(
    _ url: String,
    body: some Encodable & Sendable
) async throws -> T {
    try await NexioClient.shared.post(url, body: body)
}

// MARK: - Decoding

/// Decodes JSON on a detached task, so the client actor never does the work.
enum NexioDecoding {
    /// Decodes `data` as `T`. This is a nonisolated async function, so it runs
    /// off the client actor and inherits the caller's cancellation.
    ///
    /// JSON decoding can't be interrupted once started, so cancellation is checked
    /// before and after the work. A cancelled request never returns a value.
    static func decode<T: Decodable & Sendable>(_ type: T.Type, from data: Data) async throws -> T {
        try Task.checkCancellation()
        let value: T
        do {
            value = try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw NexioError.decodingFailed(underlying: error, data: data)
        }
        try Task.checkCancellation()
        return value
    }
}

// MARK: - URLRedactor

/// Removes secrets from URLs before they reach logs.
///
/// Query values are replaced with `REDACTED`, and user info and fragments are dropped.
enum URLRedactor {
    static func redacted(_ url: URL?) -> String {
        guard let url = url,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return "<invalid url>"
        }
        components.user = nil
        components.password = nil
        if let items = components.queryItems {
            components.queryItems = items.map { URLQueryItem(name: $0.name, value: "REDACTED") }
        }
        components.fragment = nil
        return components.string ?? "<invalid url>"
    }
}
