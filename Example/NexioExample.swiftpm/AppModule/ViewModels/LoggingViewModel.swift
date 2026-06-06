import SwiftUI
import Nexio

@MainActor
final class LoggingViewModel: ObservableObject {
    @Published var lines: [String] = []
    @Published var status: DemoStatus = .idle

    func refresh() async {
        lines = await RequestLogStore.shared.entries
    }

    func clear() async {
        await RequestLogStore.shared.clear()
        lines = []
    }

    func fireSampleRequest() async {
        status = .loading
        do {
            let posts: [Post] = try await NexioClient.shared.get("/posts?_limit=3")
            status = .success("Fetched \(posts.count) posts — see the trace below")
        } catch {
            status = .failure(describe(error))
        }
        await refresh()
    }
}
