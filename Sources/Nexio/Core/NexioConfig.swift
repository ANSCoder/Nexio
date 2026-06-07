// Copyright (c) 2026 ANSCoder
// Licensed under the MIT License. See LICENSE in the project root for details.

import Foundation

/// Configuration for ``NexioClient``.
///
/// Build a config and pass it to ``NexioClient/configure(_:)`` before making
/// your first request.
///
/// ```swift
/// var config = NexioConfig()
/// config.baseURL = URL(string: "https://api.example.com")
/// config.timeout = 15
/// config.retry = .standard
/// await NexioClient.shared.configure(config)
/// ```
public struct NexioConfig: Sendable {

    // MARK: - Nested Types

    /// Controls how much Nexio logs to the console.
    public enum LogLevel: Sendable {
        /// No logging.
        case none
        /// Logs only errors and non-2xx responses.
        case errors
        /// Logs every request and response, including headers and bodies.
        case all
    }

    // MARK: - Properties

    /// Optional base URL prepended to relative paths supplied to
    /// ``NexioClient/get(_:headers:)``, ``NexioClient/post(_:body:headers:)``, etc.
    public var baseURL: URL?

    /// Seconds before a request times out. Defaults to `30`.
    public var timeout: TimeInterval = 30

    /// Headers added to every request. Individual requests can override or
    /// extend these by passing their own `headers` dictionary.
    public var defaultHeaders: [String: String] = [
        "Content-Type": "application/json",
        "Accept": "application/json"
    ]

    /// Global retry policy. Defaults to ``RetryPolicy/none``.
    public var retry: RetryPolicy = .none

    /// Console log verbosity. Defaults to ``LogLevel/none``.
    public var logLevel: LogLevel = .none

    /// Custom `URLProtocol` classes layered onto the session ahead of the
    /// system defaults — primarily for intercepting traffic in tests (e.g.
    /// stubbing responses with a `URLProtocol` subclass). `nil` by default.
    ///
    /// - Note: `AnyClass` is not `Sendable`; this property is intentionally
    ///   exempt because protocol classes are always `NSObject` subclasses
    ///   whose class objects are global singletons — safe to share across
    ///   concurrency boundaries as long as callers pass only class literals.
    public nonisolated(unsafe) var protocolClasses: [AnyClass]?

    // MARK: - Init

    /// Creates a default configuration.
    public init() {}
}
