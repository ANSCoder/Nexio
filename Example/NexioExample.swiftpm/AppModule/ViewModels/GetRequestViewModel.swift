import SwiftUI
import Nexio

@MainActor
final class GetRequestViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var status: DemoStatus = .idle

    func loadList() async {
        status = .loading
        do {
            let posts: [Post] = try await NexioClient.shared.get("/posts?_limit=10")
            self.posts = posts
            status = .success("GET /posts → decoded \(posts.count) posts")
        } catch {
            status = .failure(describe(error))
        }
    }

    func loadSingle(id: Int) async {
        status = .loading
        do {
            let post: Post = try await NexioClient.shared.get("/posts/\(id)")
            posts = [post]
            status = .success("GET /posts/\(id) → decoded a single Post")
        } catch {
            status = .failure(describe(error))
        }
    }
}
