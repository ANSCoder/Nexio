import Foundation

/// An ``Interceptor`` that injects authentication headers from a dynamic provider.
///
/// Use this when your token can change over time (e.g. OAuth refresh).
/// For static tokens, prefer ``NexioClient/setAuth(_:)`` instead.
///
/// ```swift
/// let authInterceptor = AuthInterceptor {
///     await TokenStore.shared.currentToken()
/// }
/// await NexioClient.shared.addInterceptor(authInterceptor)
/// ```
public struct AuthInterceptor: Interceptor {

    private let provider: @Sendable () async -> AuthStrategy

    /// Creates an `AuthInterceptor` with an async strategy provider.
    ///
    /// The closure is called before each request, allowing token refresh.
    ///
    /// - Parameter provider: Async closure returning the current ``AuthStrategy``.
    public init(provider: @Sendable @escaping () async -> AuthStrategy) {
        self.provider = provider
    }

    public func adapt(_ request: URLRequest, for session: URLSession) async throws -> URLRequest {
        var mutableRequest = request
        let strategy = await provider()
        switch strategy {
        case .bearer(let token):
            mutableRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        case .apiKey(let header, let value):
            mutableRequest.setValue(value, forHTTPHeaderField: header)
        case .custom(let headers):
            headers.forEach { mutableRequest.setValue($1, forHTTPHeaderField: $0) }
        case .none:
            break
        }
        return mutableRequest
    }

    public func retry(
        _ request: URLRequest,
        dueTo error: NexioError,
        attempt: Int
    ) async -> Bool {
        false // Auth interceptor does not handle retries
    }
}
