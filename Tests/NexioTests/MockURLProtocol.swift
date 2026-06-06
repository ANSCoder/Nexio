import Foundation

// MARK: - MockURLProtocol

/// A `URLProtocol` subclass that intercepts requests in tests without hitting
/// the network. Configure stubs before each test; the handler is reset per-test
/// to prevent cross-test contamination.
///
/// **Usage**
/// ```swift
/// MockURLProtocol.stub(statusCode: 200, data: jsonData)
/// ```
final class MockURLProtocol: URLProtocol, @unchecked Sendable {

    // MARK: - Stub Types

    struct Response {
        let statusCode: Int
        let data: Data
        let headers: [String: String]

        init(statusCode: Int, data: Data, headers: [String: String] = [:]) {
            self.statusCode = statusCode
            self.data = data
            self.headers = headers
        }
    }

    // MARK: - Shared State

    /// Set this before each test. Nil causes a connection error.
    nonisolated(unsafe) static var responseStub: Response?

    // MARK: - Helpers

    /// Stubs a JSON response from an `Encodable` value.
    static func stub<T: Encodable>(statusCode: Int = 200, value: T) throws {
        let data = try JSONEncoder().encode(value)
        responseStub = Response(
            statusCode: statusCode,
            data: data,
            headers: ["Content-Type": "application/json"]
        )
    }

    /// Stubs a response from raw `Data`.
    static func stub(statusCode: Int = 200, data: Data) {
        responseStub = Response(statusCode: statusCode, data: data)
    }

    /// Stubs a response from a JSON string literal.
    static func stub(statusCode: Int = 200, json: String) {
        responseStub = Response(
            statusCode: statusCode,
            data: Data(json.utf8),
            headers: ["Content-Type": "application/json"]
        )
    }

    /// Clears the current stub.
    static func reset() {
        responseStub = nil
    }

    // MARK: - URLProtocol

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let stub = MockURLProtocol.responseStub else {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        let url = request.url ?? URL(string: "https://mock.test")!
        var allHeaders = stub.headers
        allHeaders["Content-Type"] = allHeaders["Content-Type"] ?? "application/octet-stream"
        let response = HTTPURLResponse(
            url: url,
            statusCode: stub.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: allHeaders
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

// MARK: - URLSession convenience

extension URLSession {
    /// Returns a `URLSession` that uses `MockURLProtocol` for all requests.
    static var mock: URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }
}
