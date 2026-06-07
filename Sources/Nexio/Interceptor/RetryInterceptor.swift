// Copyright (c) 2026 ANSCoder
// Licensed under the MIT License. See LICENSE in the project root for details.

import Foundation

// MARK: - RetryPolicy

/// Configures how ``RetryInterceptor`` retries failed requests.
///
/// ```swift
/// var config = NexioConfig()
/// config.retry = .standard   // 3 attempts, exponential backoff
/// ```
public struct RetryPolicy: Sendable {

    /// No retries (default).
    public static let none = RetryPolicy(maxAttempts: 0, backoff: .none)

    /// Three attempts with exponential backoff starting at 1 second.
    public static let standard = RetryPolicy(maxAttempts: 3, backoff: .exponential(base: 1.0))

    // MARK: - Nested Types

    /// Delay strategy between retry attempts.
    public enum Backoff: Sendable {
        /// No delay — retry immediately.
        case none
        /// Fixed delay of `seconds` between every retry.
        case linear(seconds: TimeInterval)
        /// Delay doubles each attempt: `base × 2^attempt` (seconds).
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
        return UInt64(seconds * 1_000_000_000)
    }
}

// MARK: - RetryInterceptor

/// An ``Interceptor`` that retries transient failures according to a ``RetryPolicy``.
///
/// Only retries on `.noInternet`, `.timeout`, or 5xx `serverError`.
/// Respects the configured ``RetryPolicy/backoff`` delay between attempts.
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
        guard attempt < policy.maxAttempts, isRetryable(error) else { return false }
        let delay = policy.delay(for: attempt)
        if delay > 0 {
            try? await Task.sleep(nanoseconds: delay)
        }
        return true
    }

    // MARK: - Private

    private func isRetryable(_ error: NexioError) -> Bool {
        switch error {
        case .noInternet, .timeout:
            return true
        case .serverError(let code, _):
            return (500...599).contains(code)
        default:
            return false
        }
    }
}