// Copyright (c) 2026 ANSCoder
// Licensed under the MIT License. See LICENSE in the project root for details.

import Foundation

// MARK: - RetryPolicy

/// Configures how Nexio retries failed requests.
///
/// Set it on ``NexioConfig/retry`` for the client's built-in retry, or pass it to
/// ``RetryInterceptor`` for explicit control.
///
/// Only idempotent methods (GET, HEAD, PUT, DELETE, OPTIONS) are retried.
/// POST and PATCH are never retried by default, because repeating them can
/// duplicate work on the server.
///
/// Retried errors are network failures, timeouts, HTTP 429, and HTTP 5xx.
///
/// ```swift
/// var config = NexioConfig()
/// config.retry = .standard   // 3 retries (up to 4 requests), exponential backoff
/// ```
public struct RetryPolicy: Sendable {

    /// No retries (default).
    public static let none = RetryPolicy(maxAttempts: 0, backoff: .none)

    /// Three retries with exponential backoff starting at 1 second.
    public static let standard = RetryPolicy(maxAttempts: 3, backoff: .exponential(base: 1.0))

    // MARK: - Nested Types

    /// Delay strategy between retry attempts.
    public enum Backoff: Sendable {
        /// No delay. Retry immediately.
        case none
        /// Fixed delay of `seconds` between every retry.
        case linear(seconds: TimeInterval)
        /// Delay doubles each attempt: `base × 2^attempt` seconds.
        case exponential(base: TimeInterval)
    }

    // MARK: - Properties

    /// Maximum number of retry attempts. `0` disables retries.
    public var maxAttempts: Int

    /// Delay strategy between attempts.
    public var backoff: Backoff

    // MARK: - Init

    /// Creates a custom retry policy.
    ///
    /// - Parameters:
    ///   - maxAttempts: Maximum retry count. Pass `0` for no retries.
    ///   - backoff: Delay strategy.
    public init(maxAttempts: Int, backoff: Backoff) {
        self.maxAttempts = maxAttempts
        self.backoff = backoff
    }

    // MARK: - Internal

    /// Longest pause between attempts. Caps exponential growth and keeps the
    /// nanosecond conversion inside `UInt64` range.
    static let maximumDelay: TimeInterval = 60

    /// Nanoseconds to sleep before attempt `attempt` (zero-based).
    func delay(for attempt: Int) -> UInt64 {
        let seconds: TimeInterval
        switch backoff {
        case .none:
            return 0
        case .linear(let s):
            seconds = s
        case .exponential(let base):
            seconds = base * pow(2.0, Double(attempt))
        }
        let clamped = min(max(seconds, 0), Self.maximumDelay)
        return UInt64(clamped * 1_000_000_000)
    }
}

// MARK: - Retry decision

extension RetryPolicy {

    /// Decides whether `request` should be retried after `error`.
    ///
    /// Sleeps for the backoff delay when it returns `true`. Returns `false`
    /// immediately if the task is cancelled, including during the sleep.
    ///
    /// - Parameters:
    ///   - request: The request that failed.
    ///   - error: The failure to evaluate.
    ///   - attempt: Zero-based attempt counter.
    /// - Returns: `true` to run another attempt.
    func shouldRetry(_ request: URLRequest, dueTo error: NexioError, attempt: Int) async -> Bool {
        guard maxAttempts > 0, attempt < maxAttempts else { return false }
        guard Self.isIdempotent(request), Self.isRetryable(error) else { return false }

        let nanoseconds = delay(for: attempt)
        if nanoseconds > 0 {
            do {
                try await Task.sleep(nanoseconds: nanoseconds)
            } catch {
                return false   // cancelled while waiting
            }
        }
        return !Task.isCancelled
    }

    /// Whether repeating `request` is safe. A missing method means GET.
    static func isIdempotent(_ request: URLRequest) -> Bool {
        let method = (request.httpMethod ?? "GET").uppercased()
        return ["GET", "HEAD", "PUT", "DELETE", "OPTIONS"].contains(method)
    }

    /// Whether `error` is transient.
    static func isRetryable(_ error: NexioError) -> Bool {
        switch error {
        case .noInternet, .timeout:
            return true
        case .serverError(let code, _):
            return code == 429 || (500...599).contains(code)
        default:
            return false
        }
    }
}

// MARK: - RetryInterceptor

/// An ``Interceptor`` that retries transient failures according to a ``RetryPolicy``.
///
/// Use it to add retry to a specific client, or to combine retry with other
/// interceptors. For the client's own retry setting, use ``NexioConfig/retry``
/// instead, so you don't end up with two retry layers.
///
/// ```swift
/// await NexioClient.shared.addInterceptor(RetryInterceptor(policy: .standard))
/// ```
public struct RetryInterceptor: Interceptor {

    private let policy: RetryPolicy

    /// Creates a `RetryInterceptor` with the given policy.
    ///
    /// - Parameter policy: Retry configuration. Defaults to ``RetryPolicy/standard``.
    public init(policy: RetryPolicy = .standard) {
        self.policy = policy
    }

    public func adapt(_ request: URLRequest, for session: URLSession) async throws -> URLRequest {
        request // pass-through
    }

    public func retry(
        _ request: URLRequest,
        dueTo error: NexioError,
        attempt: Int
    ) async -> Bool {
        await policy.shouldRetry(request, dueTo: error, attempt: attempt)
    }
}
