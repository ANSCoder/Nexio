import Testing
import Foundation
@testable import Nexio

@Suite("RetryInterceptor", .serialized)
struct RetryTests {

    private struct Dummy: Decodable, Sendable {}

    // MARK: - Basic Retry

    @Test("Retries on 503 up to maxAttempts, then throws")
    func retriesOnServerError() async throws {
        try await mockingNetwork {
            MockURLProtocol.responseStub = nil

            // Use a custom stub that always returns 503
            MockURLProtocol.stub(statusCode: 503, data: Data())

            let policy = RetryPolicy(maxAttempts: 2, backoff: .none)
            let retryInterceptor = RetryInterceptor(policy: policy)

            let client = NexioClient()
            // `URLProtocol.registerClass` only intercepts the legacy URLConnection
            // stack, never `URLSession` — route mocked traffic through
            // `NexioConfig.protocolClasses`, which `configure(_:)` wires into
            // the session it builds.
            var config = NexioConfig()
            config.protocolClasses = [MockURLProtocol.self]
            await client.configure(config)
            await client.addInterceptor(retryInterceptor)

            do {
                let _: Dummy = try await client.get("https://api.test/flaky")
                Issue.record("Expected serverError after exhausting retries")
            } catch NexioError.serverError(let code, _) {
                #expect(code == 503)
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }
    }

    // MARK: - No Retry on 4xx

    @Test("Does not retry on 401")
    func noRetryOn401() async throws {
        try await mockingNetwork {
            MockURLProtocol.stub(statusCode: 401, data: Data())

            let retryInterceptor = RetryInterceptor(policy: .standard)
            let client = NexioClient()
            var config = NexioConfig()
            config.protocolClasses = [MockURLProtocol.self]
            await client.configure(config)
            await client.addInterceptor(retryInterceptor)

            do {
                let _: Dummy = try await client.get("https://api.test/secure")
                Issue.record("Expected .unauthorized")
            } catch NexioError.unauthorized {
                // correct — should not retry
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }
    }

    // MARK: - RetryPolicy Backoff Delay

    @Test(
        "Backoff delay is calculated correctly",
        arguments: [
            (RetryPolicy.Backoff.none, 0, UInt64(0)),
            (RetryPolicy.Backoff.linear(seconds: 2.0), 0, UInt64(2_000_000_000)),
            (RetryPolicy.Backoff.exponential(base: 1.0), 0, UInt64(1_000_000_000)),
            (RetryPolicy.Backoff.exponential(base: 1.0), 1, UInt64(2_000_000_000)),
            (RetryPolicy.Backoff.exponential(base: 1.0), 2, UInt64(4_000_000_000))
        ]
    )
    func backoffDelayCalculation(backoff: RetryPolicy.Backoff, attempt: Int, expected: UInt64) {
        let policy = RetryPolicy(maxAttempts: 5, backoff: backoff)
        #expect(policy.delay(for: attempt) == expected)
    }

    // MARK: - isRetryable

    @Test(
        "Only retryable errors trigger retry",
        arguments: [
            (NexioError.noInternet, true),
            (NexioError.timeout, true),
            (NexioError.serverError(statusCode: 500, data: Data()), true),
            (NexioError.serverError(statusCode: 503, data: Data()), true),
            (NexioError.serverError(statusCode: 400, data: Data()), false),
            (NexioError.unauthorized(.test401()), false)
        ]
    )
    func retryableErrors(error: NexioError, shouldRetry: Bool) async {
        let interceptor = RetryInterceptor(policy: RetryPolicy(maxAttempts: 3, backoff: .none))
        let result = await interceptor.retry(URLRequest(url: URL(string: "https://test")!), dueTo: error, attempt: 0)
        #expect(result == shouldRetry)
    }
}

// MARK: - Helpers

// Extend HTTPURLResponse for convenience in test arguments.
//
// A `convenience init()` here would collide with NSObject's implicit
// Objective-C `init` selector — use a static factory instead.
extension HTTPURLResponse {
    static func test401() -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://test")!, statusCode: 401, httpVersion: nil, headerFields: nil)!
    }
}
