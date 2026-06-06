import Foundation

/// A hook that can inspect and mutate requests before they are sent,
/// and decide whether to retry them after a failure.
///
/// Add interceptors to a client with ``NexioClient/addInterceptor(_:)``.
/// Multiple interceptors are applied in insertion order during `adapt` and
/// reversed during `retry`.
///
/// ```swift
/// struct LoggingInterceptor: Interceptor {
///     func adapt(_ request: URLRequest, for session: URLSession) async throws -> URLRequest {
///         print("→ \(request.httpMethod ?? "") \(request.url?.absoluteString ?? "")")
///         return request
///     }
///     func retry(_ request: URLRequest, dueTo error: NexioError, attempt: Int) async -> Bool {
///         return false
///     }
/// }
/// ```
public protocol Interceptor: Sendable {

    /// Called before a request is dispatched.
    ///
    /// Mutate `request` to inject headers, sign the request, etc., then return it.
    ///
    /// - Parameters:
    ///   - request: The outgoing `URLRequest`.
    ///   - session: The session that will execute the request.
    /// - Returns: The (possibly mutated) request.
    func adapt(_ request: URLRequest, for session: URLSession) async throws -> URLRequest

    /// Called after a request fails.
    ///
    /// Return `true` to trigger a retry. The client retries immediately; combine
    /// with ``RetryPolicy`` backoff for delay-based retries.
    ///
    /// - Parameters:
    ///   - request: The request that failed.
    ///   - error: The ``NexioError`` that caused the failure.
    ///   - attempt: Zero-based retry counter (0 = first failure).
    /// - Returns: `true` to retry, `false` to propagate the error.
    func retry(_ request: URLRequest, dueTo error: NexioError, attempt: Int) async -> Bool
}
