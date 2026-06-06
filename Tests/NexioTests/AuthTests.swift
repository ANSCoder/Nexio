import Testing
import Foundation
@testable import Nexio

@Suite("Authentication")
struct AuthTests {

    private struct EmptyResponse: Decodable, Sendable {}

    // MARK: - AuthStrategy Header Injection

    @Test(
        "setAuth injects correct header",
        arguments: [
            AuthStrategy.bearer("tok123"),
            AuthStrategy.apiKey(header: "X-Api-Key", value: "secret"),
            AuthStrategy.custom(["X-Custom": "value"])
        ]
    )
    func authHeaderInjected(strategy: AuthStrategy) async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.stub(json: "{}")
        // Capture the adapted request via an interceptor
        let capture = CapturingInterceptor { capturedRequest = $0 }

        URLProtocol.registerClass(MockURLProtocol.self)
        let client = NexioClient()
        await client.addInterceptor(capture)
        await client.setAuth(strategy)

        let _: EmptyResponse? = try? await client.get("https://api.test/me")

        let req = try #require(capturedRequest)
        switch strategy {
        case .bearer(let token):
            #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer \(token)")
        case .apiKey(let header, let value):
            #expect(req.value(forHTTPHeaderField: header) == value)
        case .custom(let headers):
            for (key, val) in headers {
                #expect(req.value(forHTTPHeaderField: key) == val)
            }
        case .none:
            break
        }
    }

    // MARK: - Endpoint Auth Override

    @Test("Endpoint .none auth skips global bearer token")
    func endpointNoneSkipsGlobalAuth() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.stub(json: "{}")
        let capture = CapturingInterceptor { capturedRequest = $0 }

        URLProtocol.registerClass(MockURLProtocol.self)
        let client = NexioClient()
        await client.addInterceptor(capture)
        await client.setAuth(.bearer("global-token"))

        struct NoAuthEndpoint: Endpoint {
            var baseURL: URL { URL(string: "https://api.test")! }
            var path: String { "/public" }
            var method: HTTPMethod { .get }
            var auth: AuthStrategy? { .none }
        }

        let _: EmptyResponse? = try? await client.request(NoAuthEndpoint())
        let req = try #require(capturedRequest)
        #expect(req.value(forHTTPHeaderField: "Authorization") == nil)
    }

    // MARK: - AuthInterceptor

    @Test("AuthInterceptor injects dynamically provided token")
    func authInterceptorDynamic() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.stub(json: "{}")
        let capture = CapturingInterceptor { capturedRequest = $0 }

        URLProtocol.registerClass(MockURLProtocol.self)

        let dynamicToken = "dynamic-abc"
        let authInterceptor = AuthInterceptor { .bearer(dynamicToken) }

        let client = NexioClient()
        await client.addInterceptor(authInterceptor)
        await client.addInterceptor(capture)

        let _: EmptyResponse? = try? await client.get("https://api.test/secure")
        let req = try #require(capturedRequest)
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer \(dynamicToken)")
    }
}

// MARK: - Helpers

/// Interceptor that captures the adapted request for assertion.
private struct CapturingInterceptor: Interceptor {
    let onAdapt: @Sendable (URLRequest) -> Void

    func adapt(_ request: URLRequest, for session: URLSession) async throws -> URLRequest {
        onAdapt(request)
        return request
    }

    func retry(_ request: URLRequest, dueTo error: NexioError, attempt: Int) async -> Bool {
        false
    }
}
