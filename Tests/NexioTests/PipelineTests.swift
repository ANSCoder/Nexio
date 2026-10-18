// Copyright (c) 2026 ANSCoder
// Licensed under the MIT License. See LICENSE in the project root for details.

import Testing
import Foundation
@testable import Nexio

@Suite("Request pipeline", .serialized)
struct PipelineTests {

    private struct Empty: Codable, Sendable {}

    private struct SecureEndpoint: Endpoint {
        let auth: AuthStrategy?
        var baseURL: URL { URL(string: "https://api.test")! }
        var path: String { "/me" }
        var method: HTTPMethod { .get }
    }

    private func makeClient(retry: RetryPolicy = .none) async -> NexioClient {
        let client = NexioClient()
        var config = NexioConfig()
        config.protocolClasses = [MockURLProtocol.self]
        config.retry = retry
        await client.configure(config)
        return client
    }

    // MARK: - Retry

    @Test("Config retry retries 5xx and makes maxAttempts + 1 total requests")
    func configRetryRetriesServerErrors() async throws {
        try await mockingNetwork {
            MockURLProtocol.requestCount = 0
            MockURLProtocol.stub(statusCode: 503, data: Data())
            let client = await makeClient(retry: RetryPolicy(maxAttempts: 2, backoff: .none))

            do {
                let _: Empty = try await client.get("https://api.test/flaky")
                Issue.record("Expected serverError after retries")
            } catch NexioError.serverError(let code, _) {
                #expect(code == 503)
            }
            #expect(MockURLProtocol.requestCount == 3)
        }
    }

    @Test("POST is never retried by default, even on 503")
    func postIsNotRetried() async throws {
        try await mockingNetwork {
            MockURLProtocol.requestCount = 0
            MockURLProtocol.stub(statusCode: 503, data: Data())
            let client = await makeClient(retry: RetryPolicy(maxAttempts: 3, backoff: .none))

            do {
                let _: Empty = try await client.post("https://api.test/orders", body: Empty())
                Issue.record("Expected serverError")
            } catch NexioError.serverError(_, _) {
                // expected
            }
            #expect(MockURLProtocol.requestCount == 1)
        }
    }

    @Test("Reconfiguring with retry disabled turns retry off")
    func reconfigureDisablesRetry() async throws {
        try await mockingNetwork {
            MockURLProtocol.requestCount = 0
            MockURLProtocol.stub(statusCode: 503, data: Data())
            let client = await makeClient(retry: RetryPolicy(maxAttempts: 2, backoff: .none))
            var config = NexioConfig()
            config.protocolClasses = [MockURLProtocol.self]
            config.retry = .none
            await client.configure(config)

            do {
                let _: Empty = try await client.get("https://api.test/flaky")
                Issue.record("Expected serverError")
            } catch NexioError.serverError(_, _) {
                // expected
            }
            #expect(MockURLProtocol.requestCount == 1)
        }
    }

    // MARK: - Auth

    @Test("Endpoint auth replaces the dynamic AuthInterceptor token")
    func endpointAuthWins() async throws {
        try await mockingNetwork {
            MockURLProtocol.requestCount = 0
            MockURLProtocol.stub(statusCode: 200, json: "{}")
            let client = await makeClient()
            await client.addInterceptor(AuthInterceptor { .bearer("dynamic") })

            let _: Empty = try await client.request(SecureEndpoint(auth: .bearer("endpoint")))

            #expect(MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer endpoint")
        }
    }

    @Test("Endpoint auth .some(.none) sends no token even with a dynamic provider")
    func noneEndpointSendsNoToken() async throws {
        try await mockingNetwork {
            MockURLProtocol.requestCount = 0
            MockURLProtocol.stub(statusCode: 200, json: "{}")
            let client = await makeClient()
            await client.addInterceptor(AuthInterceptor { .bearer("dynamic") })

            let _: Empty = try await client.request(SecureEndpoint(auth: .some(.none)))

            #expect(MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization") == nil)
        }
    }

    @Test("Requests without an endpoint override still get the dynamic token")
    func dynamicTokenStillApplied() async throws {
        try await mockingNetwork {
            MockURLProtocol.requestCount = 0
            MockURLProtocol.stub(statusCode: 200, json: "{}")
            let client = await makeClient()
            await client.addInterceptor(AuthInterceptor { .bearer("dynamic") })

            let _: Empty = try await client.get("https://api.test/me")

            #expect(MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer dynamic")
        }
    }

    @Test("Explicit no-auth strips credentials from default headers")
    func noneStripsDefaultCredentialHeaders() async throws {
        try await mockingNetwork {
            MockURLProtocol.requestCount = 0
            MockURLProtocol.stub(statusCode: 200, json: "{}")
            let client = NexioClient()
            var config = NexioConfig()
            config.protocolClasses = [MockURLProtocol.self]
            config.defaultHeaders["Authorization"] = "Bearer leaked"
            config.defaultHeaders["X-Api-Key"] = "leaked-key"
            config.defaultHeaders["Cookie"] = "session=leaked"
            await client.configure(config)

            let _: Empty = try await client.request(SecureEndpoint(auth: .some(.none)))

            let sent = MockURLProtocol.lastRequest
            #expect(sent?.value(forHTTPHeaderField: "Authorization") == nil)
            #expect(sent?.value(forHTTPHeaderField: "X-Api-Key") == nil)
            #expect(sent?.value(forHTTPHeaderField: "Cookie") == nil)
            #expect(sent?.httpShouldHandleCookies == false)
        }
    }

    @Test("Explicit no-auth strips credentials from endpoint headers")
    func noneStripsEndpointCredentialHeaders() async throws {
        try await mockingNetwork {
            MockURLProtocol.requestCount = 0
            MockURLProtocol.stub(statusCode: 200, json: "{}")
            let client = await makeClient()

            struct HeaderEndpoint: Endpoint {
                var baseURL: URL { URL(string: "https://api.test")! }
                var path: String { "/status" }
                var method: HTTPMethod { .get }
                var headers: [String: String] { ["Authorization": "Bearer inline"] }
                var auth: AuthStrategy? { .some(.none) }
            }

            let _: Empty = try await client.request(HeaderEndpoint())

            #expect(MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization") == nil)
        }
    }

    @Test("Log redaction hides query values, user info, and fragments")
    func redactsQueryValues() {
        let url = URL(string: "https://user:pw@api.test/users?access_token=abc123&page=2&Signature=xyz#secret-fragment")
        let text = URLRedactor.redacted(url)
        #expect(!text.contains("abc123"))
        #expect(!text.contains("xyz"))
        #expect(!text.contains("pw@"))
        #expect(!text.contains("secret-fragment"))
        #expect(text.contains("page=REDACTED"))
        #expect(text.contains("REDACTED"))
    }
}
