import SwiftUI
import Nexio

@MainActor
final class RetryViewModel: ObservableObject {
    @Published var status: DemoStatus = .idle
    @Published var attemptLog: [String] = []

    /// httpstat.us/<code> is a public test service that returns whatever
    /// status code you ask for — perfect for forcing retryable failures
    /// without standing up a server.
    func trigger(statusCode: Int) async {
        status = .loading
        attemptLog = []
        await RequestLogStore.shared.clear()

        struct Empty: Decodable, Sendable {}
        do {
            let _: Empty = try await NexioClient.shared.get("https://httpstat.us/\(statusCode)")
            status = .success("Request succeeded")
        } catch {
            status = .failure("Gave up after retries: \(describe(error))")
        }
        attemptLog = await RequestLogStore.shared.entries
    }
}
