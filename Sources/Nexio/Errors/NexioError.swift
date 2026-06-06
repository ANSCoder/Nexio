import Foundation

/// Typed errors surfaced by all Nexio operations.
///
/// Catch `NexioError` to distinguish network problems from decode failures
/// or auth issues without parsing raw `NSError` codes.
public enum NexioError: Error, LocalizedError, Sendable {

    /// The provided URL string could not be parsed into a valid `URL`.
    case invalidURL(String)

    /// The device has no network connectivity (`NSURLErrorNotConnectedToInternet`).
    case noInternet

    /// The request exceeded the configured timeout interval.
    case timeout

    /// The server returned HTTP 401.
    case unauthorized(HTTPURLResponse)

    /// The server returned HTTP 404.
    case notFound(HTTPURLResponse)

    /// The server returned a 5xx or other unexpected status code.
    case serverError(statusCode: Int, data: Data)

    /// `JSONDecoder` failed to decode the response body.
    case decodingFailed(underlying: any Error, data: Data)

    /// Any error not covered by the cases above.
    case unknown(underlying: any Error)

    // MARK: - LocalizedError

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .noInternet:
            return "No internet connection."
        case .timeout:
            return "The request timed out."
        case .unauthorized:
            return "Unauthorized (401)."
        case .notFound:
            return "Resource not found (404)."
        case .serverError(let code, _):
            return "Server error (\(code))."
        case .decodingFailed(let err, _):
            return "Decoding failed: \(err.localizedDescription)"
        case .unknown(let err):
            return "Unknown error: \(err.localizedDescription)"
        }
    }
}
