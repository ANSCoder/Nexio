import Foundation

// MARK: - NexioClient

/// The main entry point for Nexio networking.
///
/// `NexioClient` is a Swift actor — all configuration mutations and requests
/// are automatically serialised, giving you zero data-race risk.
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

    // MARK: - Private State

    private var config: NexioConfig = NexioConfig()
    private var authStrategy: AuthStrategy = .none
    private var interceptors: [any Interceptor] = []
    private var session: URLSession = URLSession.shared
    private let decoder: JSONDecoder = JSONDecoder()

    // MARK: - Init

    /// Creates a standalone client. Use ``shared`` for typical app usage.
    public init() {}

    // MARK: - Configuration

    /// Applies a new configuration. Rebuilds the underlying `URLSession`.
    ///
    /// - Parameter config: The configuration to apply.
    public func configure(_ config: NexioConfig) {
        self.config = config
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = config.timeout
        sessionConfig.httpAdditionalHeaders = config.defaultHeaders as [AnyHashable: Any]
        session = URLSession(configuration: sessionConfig)
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
        return try await perform(request)
    }

    /// Performs a POST request, encoding `body` as JSON, and decodes the response.
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
        return try await perform(request)
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
        return try await perform(request)
    }

    /// Performs a PATCH request, encoding `body` as JSON, and decodes the response.
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
        return try await perform(request)
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
        let (_, http) = try await executeWithInterceptors(request, attempt: 0)
        if let error = http.nexioError(data: Data()) {
            throw error
        }
    }

    // MARK: - Typed Endpoint

    /// Performs a request described by a typed ``Endpoint`` conformer and decodes
    /// the JSON response.
    ///
    /// ```swift
    /// let user: User = try await Nexio.shared.request(GetUserEndpoint(id: 42))
    /// ```
    ///
    /// - Parameter endpoint: The endpoint to execute.
    /// - Returns: Decoded value of type `T`.
    /// - Throws: ``NexioError``
    public func request<T: Decodable & Sendable>(_ endpoint: some Endpoint) async throws -> T {
        let urlRequest = try buildRequest(from: endpoint)
        return try await perform(urlRequest)
    }

    // MARK: - Raw Data

    /// Fetches raw `Data` from a URL — used internally by ``ImageLoader``.
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
        let (data, http) = try await executeWithInterceptors(request, attempt: 0)
        if let error = http.nexioError(data: data) { throw error }
        return data
    }

    // MARK: - Private Helpers

    /// Runs a built request through the interceptor/retry pipeline, maps
    /// failure status codes to ``NexioError``, and decodes a successful
    /// response body as `T`.
    ///
    /// Shared tail end for every JSON-returning call (`get`, `post`, `put`,
    /// `patch`, ``request(_:)``) — keeps status mapping, logging, and
    /// decode-error wrapping in one place.
    ///
    /// - Parameter request: The fully-built request to execute.
    /// - Returns: The decoded response body.
    /// - Throws: ``NexioError/decodingFailed(underlying:data:)`` if `T`
    ///   doesn't match the response shape, or any status-mapped ``NexioError``.
    private func perform<T: Decodable & Sendable>(_ request: URLRequest) async throws -> T {
        let (data, http) = try await executeWithInterceptors(request, attempt: 0)
        if let error = http.nexioError(data: data) { throw error }
        logIfNeeded(request: request, response: http, data: data)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NexioError.decodingFailed(underlying: error, data: data)
        }
    }

    /// Adapts, sends, and — on failure — retries a request, consulting every
    /// registered ``Interceptor`` along the way.
    ///
    /// Adapters run in insertion order before the request is sent; on
    /// failure, retry handlers run in *reverse* insertion order so the most
    /// specific interceptor gets first say. The first handler that returns
    /// `true` wins and the whole pipeline restarts.
    ///
    /// - Note: A retry restarts from the **original** `request`, not the
    ///   already-`adapted` one — each attempt re-runs the full adapter chain
    ///   from scratch, so e.g. a token-refreshing ``AuthInterceptor`` mints a
    ///   fresh credential per attempt instead of resending a stale one.
    ///
    /// - Parameters:
    ///   - request: The request to send (pre-adaptation).
    ///   - attempt: Zero-based retry counter, threaded through to
    ///     ``Interceptor/retry(_:dueTo:attempt:)``.
    /// - Returns: Raw response data and the parsed `HTTPURLResponse`.
    /// - Throws: The ``NexioError`` from the final attempt, if no
    ///   interceptor opts to retry.
    private func executeWithInterceptors(
        _ request: URLRequest,
        attempt: Int
    ) async throws -> (Data, HTTPURLResponse) {
        var adapted = request
        for interceptor in interceptors {
            adapted = try await interceptor.adapt(adapted, for: session)
        }

        do {
            let result = try await session.nexioData(for: adapted)
            return result
        } catch let nexioError as NexioError {
            // Walk interceptors in reverse for retry decisions
            for interceptor in interceptors.reversed() {
                if await interceptor.retry(adapted, dueTo: nexioError, attempt: attempt) {
                    return try await executeWithInterceptors(request, attempt: attempt + 1)
                }
            }
            throw nexioError
        }
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
            request.httpBody = try JSONEncoder().encode(body)
        }
        return request
    }

    /// Builds a `URLRequest` from a typed ``Endpoint``: composes `baseURL` +
    /// `path` + query items, merges headers, resolves per-endpoint vs. global
    /// auth, and JSON-encodes the endpoint's body if present.
    ///
    /// - Note: ``Endpoint/auth`` wins over the client's global auth strategy
    ///   whenever it's non-`nil` — see ``Endpoint/auth`` for the
    ///   `AuthStrategy?` semantics (and the `.none` ambiguity to watch for).
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
        let effectiveAuth = endpoint.auth ?? authStrategy
        applyAuth(effectiveAuth, to: &request)

        if let body = endpoint.body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        return request
    }

    /// Resolves a user-supplied string to an absolute `URL`.
    ///
    /// Strings that already parse with a scheme (e.g. `"https://..."`) pass
    /// through unchanged; anything else is treated as a path and appended to
    /// ``NexioConfig/baseURL``. Returns `nil` — surfaced by callers as
    /// ``NexioError/invalidURL(_:)`` — when neither applies, e.g. a malformed
    /// string with no `baseURL` configured to fall back on.
    ///
    /// - Parameter urlString: Absolute URL string, or a relative path.
    /// - Returns: The resolved `URL`, or `nil` if it can't be resolved.
    private func resolve(_ urlString: String) -> URL? {
        if let absolute = URL(string: urlString), absolute.scheme != nil {
            return absolute
        }
        return config.baseURL.map { $0.appendingPathComponent(urlString) }
    }

    /// Merges ``NexioConfig/defaultHeaders`` onto `request`, overwriting any
    /// existing values for the same field names.
    ///
    /// - Parameter request: The request to mutate in place.
    private func applyDefaultHeaders(to request: inout URLRequest) {
        config.defaultHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }
    }

    /// Applies an ``AuthStrategy`` to `request` by setting the appropriate
    /// header(s); `.none` is a deliberate no-op.
    ///
    /// - Parameters:
    ///   - strategy: The strategy to apply — global or per-endpoint.
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
    /// silent for `.none`, failures only for `.errors`, full request + response
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
            print("[Nexio] ❌ \(request.httpMethod ?? "?") \(request.url?.absoluteString ?? "") → \(response.statusCode)")
        case .all:
            print("[Nexio] ➡️  \(request.httpMethod ?? "?") \(request.url?.absoluteString ?? "")")
            print("[Nexio] ⬅️  \(response.statusCode) (\(data.count) bytes)")
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
