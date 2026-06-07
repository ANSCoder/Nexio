/// Authentication strategy applied to outgoing requests.
///
/// Pass to ``NexioClient/setAuth(_:)`` for global auth, or set
/// ``Endpoint/auth`` on individual endpoints to override per-request.
///
/// ```swift
/// await NexioClient.shared.setAuth(.bearer("my-token"))
/// ```
public enum AuthStrategy: Sendable {

    /// Adds `Authorization: Bearer <token>`.
    case bearer(String)

    /// Adds a custom header with the given name and value.
    ///
    /// - Parameters:
    ///   - header: The HTTP header field name (e.g. `"X-Api-Key"`).
    ///   - value: The header value.
    case apiKey(header: String, value: String)

    /// Injects an arbitrary set of key-value headers.
    case custom([String: String])

    /// Skips authentication entirely for this request.
    case none
}
