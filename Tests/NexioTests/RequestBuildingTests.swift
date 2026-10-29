// Copyright (c) 2026 ANSCoder
// Licensed under the MIT License. See LICENSE in the project root for details.

import Testing
import Foundation
@testable import Nexio

@Suite("Request building", .serialized)
struct RequestBuildingTests {

    private struct Empty: Codable, Sendable {}

    private actor Recorder {
        private(set) var last: URLRequest?
        func record(_ request: URLRequest) { last = request }
    }

    private struct RecordingInterceptor: Interceptor {
        let recorder: Recorder

        func adapt(_ request: URLRequest, for session: URLSession) async throws -> URLRequest {
            await recorder.record(request)
            return request
        }

        func retry(_ request: URLRequest, dueTo error: NexioError, attempt: Int) async -> Bool {
            false
        }
    }

    private func makeClient(recorder: Recorder) async -> NexioClient {
        var config = NexioConfig()
        config.baseURL = URL(string: "https://api.test")
        config.protocolClasses = [MockURLProtocol.self]
        let client = NexioClient()
        await client.configure(config)
        await client.addInterceptor(RecordingInterceptor(recorder: recorder))
        return client
    }

    @Test("Relative path keeps its query string")
    func relativePathKeepsQuery() async throws {
        try await mockingNetwork {
            MockURLProtocol.stub(json: "{}")
            let recorder = Recorder()
            let client = await makeClient(recorder: recorder)

            let _: Empty? = try? await client.get("users?page=2")
            #expect(await recorder.last?.url?.absoluteString == "https://api.test/users?page=2")
        }
    }

    @Test("Query with a raw space is percent-encoded, not sent unencoded")
    func rawSpaceInQueryIsEncoded() async throws {
        try await mockingNetwork {
            // Set the stub explicitly: a leftover stub from another test must not decide the outcome.
            MockURLProtocol.stub(json: "{}")
            let recorder = Recorder()
            let client = await makeClient(recorder: recorder)

            let _: Empty = try await client.get("users?q=a b")
            #expect(await recorder.last?.url?.absoluteString == "https://api.test/users?q=a%20b")
        }
    }

    @Test("Global auth is sent to the baseURL host only")
    func globalAuthStaysOnBaseHost() async throws {
        try await mockingNetwork {
            MockURLProtocol.stub(json: "{}")
            let recorder = Recorder()
            let client = await makeClient(recorder: recorder)
            await client.setAuth(.bearer("secret"))

            let _: Empty = try await client.get("https://other.test/track")
            #expect(await recorder.last?.value(forHTTPHeaderField: "Authorization") == nil)

            let _: Empty = try await client.get("users")
            #expect(await recorder.last?.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
        }
    }

    @Test("AuthInterceptor token is not sent to other hosts")
    func dynamicAuthStaysOnBaseHost() async throws {
        try await mockingNetwork {
            MockURLProtocol.stub(json: "{}")
            let recorder = Recorder()
            var config = NexioConfig()
            config.baseURL = URL(string: "https://api.test")
            config.protocolClasses = [MockURLProtocol.self]
            let client = NexioClient()
            await client.configure(config)
            // Added before the recorder, so the recorder sees the adapted request.
            await client.addInterceptor(AuthInterceptor { .bearer("dyn") })
            await client.addInterceptor(RecordingInterceptor(recorder: recorder))

            let _: Empty = try await client.get("https://other.test/track")
            #expect(await recorder.last?.value(forHTTPHeaderField: "Authorization") == nil)

            let _: Empty = try await client.get("users")
            #expect(await recorder.last?.value(forHTTPHeaderField: "Authorization") == "Bearer dyn")
        }
    }
}
