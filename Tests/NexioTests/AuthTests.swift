// Copyright (c) 2026 ANSCoder
// Licensed under the MIT License. See LICENSE in the project root for details.

import Testing
import Foundation
@testable import Nexio

@Suite("Authentication", .serialized)
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
        try await mockingNetwork {
            let store = RequestCapture()
            MockURLProtocol.stub(json: "{}")
            // Capture the adapted request via an interceptor
            let capture = CapturingInterceptor(store: store)

            let client = NexioClient()
            await client.addInterceptor(capture)
            await client.setAuth(strategy)

            let _: EmptyResponse? = try? await client.get("https://api.test/me")

            let req = try #require(await store.request)
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
    }

    // MARK: - Endpoint Auth Override

    @Test("Endpoint .none auth skips global bearer token")
    func endpointNoneSkipsGlobalAuth() async throws {
        try await mockingNetwork {
            let store = RequestCapture()
            MockURLProtocol.stub(json: "{}")
            let capture = CapturingInterceptor(store: store)

            let client = NexioClient()
            await client.addInterceptor(capture)
            await client.setAuth(.bearer("global-token"))

            struct NoAuthEndpoint: Endpoint {
                var baseURL: URL { URL(string: "https://api.test")! }
                var path: String { "/public" }
                var method: HTTPMethod { .get }
                // `.none` here means `AuthStrategy.none` (skip auth), not
                // `Optional<AuthStrategy>.none` (inherit) — spell it out to
                // dodge the footgun the compiler is warning about.
                var auth: AuthStrategy? { .some(.none) }
            }

            let _: EmptyResponse? = try? await client.request(NoAuthEndpoint())
            let req = try #require(await store.request)
            #expect(req.value(forHTTPHeaderField: "Authorization") == nil)
        }
    }

    // MARK: - AuthInterceptor

    @Test("AuthInterceptor injects dynamically provided token")
    func authInterceptorDynamic() async throws {
        try await mockingNetwork {
            let store = RequestCapture()
            MockURLProtocol.stub(json: "{}")
            let capture = CapturingInterceptor(store: store)

            let dynamicToken = "dynamic-abc"
            let authInterceptor = AuthInterceptor { .bearer(dynamicToken) }

            let client = NexioClient()
            await client.addInterceptor(authInterceptor)
            await client.addInterceptor(capture)

            let _: EmptyResponse? = try? await client.get("https://api.test/secure")
            let req = try #require(await store.request)
            #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer \(dynamicToken)")
        }
    }
}

// MARK: - Helpers

/// Actor-backed sink so captures from concurrently-executing interceptor
/// calls can't race — a plain `var` capture isn't `Sendable`-safe here.
private actor RequestCapture {
    private(set) var request: URLRequest?

    func capture(_ request: URLRequest) {
        self.request = request
    }
}

/// Interceptor that captures the adapted request for assertion.
private struct CapturingInterceptor: Interceptor {
    let store: RequestCapture

    func adapt(_ request: URLRequest, for session: URLSession) async throws -> URLRequest {
        await store.capture(request)
        return request
    }

    func retry(_ request: URLRequest, dueTo error: NexioError, attempt: Int) async -> Bool {
        false
    }
}