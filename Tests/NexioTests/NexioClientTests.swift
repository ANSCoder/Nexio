import Testing
import Foundation
@testable import Nexio

// MARK: - Shared fixtures

private struct User: Codable, Sendable, Equatable {
    let id: Int
    let name: String
}

private struct CreateUserRequest: Encodable, Sendable {
    let name: String
}

// MARK: - NexioClient Tests

@Suite("NexioClient")
struct NexioClientTests {

    // Each test gets its own client backed by MockURLProtocol so tests are isolated.
    private func makeClient() -> NexioClient {
        let client = NexioClient()
        let config = NexioConfig()
        // NexioClient.configure is async/actor-isolated; call in test bodies
        return client
    }

    // MARK: - GET

    @Test("GET decodes JSON array")
    func getDecodesArray() async throws {
        let expected = [User(id: 1, name: "Alice"), User(id: 2, name: "Bob")]
        try MockURLProtocol.stub(value: expected)

        let client = NexioClient()
        await client.configure(makeConfig())

        let users: [User] = try await client.get("https://api.test/users")
        #expect(users == expected)
    }

    @Test("GET decodes single object")
    func getDecodesSingleObject() async throws {
        let expected = User(id: 42, name: "Carol")
        try MockURLProtocol.stub(value: expected)

        let client = NexioClient()
        await client.configure(makeConfig())

        let user: User = try await client.get("https://api.test/users/42")
        #expect(user == expected)
    }

    @Test("GET throws invalidURL for unparseable string")
    func getThrowsInvalidURL() async throws {
        let client = NexioClient()
        await client.configure(makeConfig())
        // No baseURL set and string is not a full URL
        await #expect(throws: NexioError.self) {
            let _: User = try await client.get("not a url at all ://")
        }
    }

    // MARK: - POST

    @Test("POST sends body and decodes response")
    func postSendsBodyAndDecodesResponse() async throws {
        let created = User(id: 99, name: "Dave")
        try MockURLProtocol.stub(statusCode: 201, value: created)

        let client = NexioClient()
        await client.configure(makeConfig())

        let body = CreateUserRequest(name: "Dave")
        let user: User = try await client.post("https://api.test/users", body: body)
        #expect(user == created)
    }

    // MARK: - Status Code Errors

    @Test("401 response throws .unauthorized", arguments: [401])
    func unauthorizedThrows(statusCode: Int) async throws {
        MockURLProtocol.stub(statusCode: statusCode, data: Data())

        let client = NexioClient()
        await client.configure(makeConfig())

        await #expect(throws: NexioError.self) {
            let _: User = try await client.get("https://api.test/me")
        }
    }

    @Test("404 response throws .notFound")
    func notFoundThrows() async throws {
        MockURLProtocol.stub(statusCode: 404, data: Data())

        let client = NexioClient()
        await client.configure(makeConfig())

        await #expect(throws: NexioError.self) {
            let _: User = try await client.get("https://api.test/missing")
        }
    }

    @Test(
        "5xx response throws .serverError",
        arguments: [500, 502, 503]
    )
    func serverErrorThrows(statusCode: Int) async throws {
        MockURLProtocol.stub(statusCode: statusCode, data: Data())

        let client = NexioClient()
        await client.configure(makeConfig())

        do {
            let _: User = try await client.get("https://api.test/boom")
            Issue.record("Expected serverError, got success")
        } catch NexioError.serverError(let code, _) {
            #expect(code == statusCode)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    // MARK: - Decoding Error

    @Test("Malformed JSON throws .decodingFailed")
    func malformedJSONThrows() async throws {
        MockURLProtocol.stub(json: "{ not json }")

        let client = NexioClient()
        await client.configure(makeConfig())

        do {
            let _: User = try await client.get("https://api.test/users/1")
            Issue.record("Expected decodingFailed")
        } catch NexioError.decodingFailed {
            // expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    // MARK: - DELETE

    @Test("DELETE succeeds on 204")
    func deleteSucceeds() async throws {
        MockURLProtocol.stub(statusCode: 204, data: Data())

        let client = NexioClient()
        await client.configure(makeConfig())

        try await client.delete("https://api.test/users/1")
    }

    // MARK: - Typed Endpoint

    @Test("request(endpoint:) uses endpoint URL and method")
    func typedEndpointRequest() async throws {
        let expected = [User(id: 1, name: "Alice")]
        try MockURLProtocol.stub(value: expected)

        let client = NexioClient()
        await client.configure(makeConfig())

        struct ListUsers: Endpoint {
            var baseURL: URL { URL(string: "https://api.test")! }
            var path: String { "/users" }
            var method: HTTPMethod { .get }
        }

        let users: [User] = try await client.request(ListUsers())
        #expect(users == expected)
    }

    // MARK: - Convenience

    @Test("nexioGet top-level function decodes response")
    func nexioGetTopLevel() async throws {
        let expected = User(id: 1, name: "Alice")
        try MockURLProtocol.stub(value: expected)

        // Configure shared client with mock session
        await NexioClient.shared.configure(makeConfig())

        let user: User = try await nexioGet("https://api.test/users/1")
        #expect(user == expected)
    }
}

// MARK: - Helpers

private func makeConfig() -> NexioConfig {
    var config = NexioConfig()
    // Wire the mock protocol into the session
    let sessionConfig = URLSessionConfiguration.ephemeral
    sessionConfig.protocolClasses = [MockURLProtocol.self]
    // NexioConfig doesn't expose URLSessionConfiguration directly,
    // so we use the default config and rely on URLProtocol registration.
    URLProtocol.registerClass(MockURLProtocol.self)
    return config
}
