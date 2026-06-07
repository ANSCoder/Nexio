// Copyright (c) 2026 ANSCoder
// Licensed under the MIT License. See LICENSE in the project root for details.

import Foundation

/// HTTP methods supported by ``NexioClient``.
public enum HTTPMethod: String, Sendable {
    case get    = "GET"
    case post   = "POST"
    case put    = "PUT"
    case patch  = "PATCH"
    case delete = "DELETE"
}

/// A type-safe description of a single API endpoint.
///
/// Conform your own types to `Endpoint` to group related requests and keep
/// URL construction out of call sites.
///
/// ```swift
/// struct UsersEndpoint: Endpoint {
///     var baseURL: URL { URL(string: "https://api.example.com")! }
///     var path: String { "/users" }
///     var method: HTTPMethod { .get }
/// }
///
/// let users: [User] = try await NexioClient.shared.request(UsersEndpoint())
/// ```
public protocol Endpoint: Sendable {

    /// Root URL for this endpoint (e.g. `https://api.example.com`).
    var baseURL: URL { get }

    /// Path component appended to ``baseURL`` (e.g. `"/users/42"`).
    var path: String { get }

    /// HTTP method.
    var method: HTTPMethod { get }

    /// Extra headers merged on top of ``NexioConfig/defaultHeaders``.
    var headers: [String: String] { get }

    /// Query parameters appended to the URL.
    var queryItems: [URLQueryItem] { get }

    /// Optional JSON-encodable request body.
    var body: (any Encodable)? { get }

    /// Per-request auth override.
    ///
    /// - `nil` — inherit the global ``AuthStrategy`` set on ``NexioClient``.
    /// - `.none` — skip auth entirely for this request.
    /// - Any other value — use it instead of the global strategy.
    var auth: AuthStrategy? { get }
}

// MARK: - Default Implementations

public extension Endpoint {
    var headers: [String: String] { [:] }
    var queryItems: [URLQueryItem] { [] }
    var body: (any Encodable)? { nil }
    var auth: AuthStrategy? { nil }
}