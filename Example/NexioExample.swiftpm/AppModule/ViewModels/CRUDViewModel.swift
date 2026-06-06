import SwiftUI
import Nexio

@MainActor
final class CRUDViewModel: ObservableObject {
    @Published var title = "Hello, Nexio"
    @Published var body  = "Created from the Nexio example app."
    @Published var status: DemoStatus = .idle
    @Published var lastResult: Post?

    func create() async {
        await run("POST /posts") {
            try await NexioClient.shared.post(
                "/posts",
                body: NewPost(userId: 1, title: self.title, body: self.body)
            )
        }
    }

    func replace() async {
        await run("PUT /posts/1") {
            try await NexioClient.shared.put(
                "/posts/1",
                body: NewPost(userId: 1, title: self.title, body: self.body)
            )
        }
    }

    func patchTitle() async {
        await run("PATCH /posts/1") {
            try await NexioClient.shared.patch("/posts/1", body: ["title": self.title])
        }
    }

    func delete() async {
        status = .loading
        do {
            try await NexioClient.shared.delete("/posts/1")
            lastResult = nil
            status = .success("DELETE /posts/1 → succeeded (no body to decode)")
        } catch {
            status = .failure(describe(error))
        }
    }

    private func run(_ label: String, _ operation: @escaping () async throws -> Post) async {
        status = .loading
        do {
            let result = try await operation()
            lastResult = result
            status = .success("\(label) → #\(result.id) \u{201C}\(result.title)\u{201D}")
        } catch {
            status = .failure(describe(error))
        }
    }
}
