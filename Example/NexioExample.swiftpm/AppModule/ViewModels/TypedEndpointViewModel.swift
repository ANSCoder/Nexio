import SwiftUI
import Nexio

@MainActor
final class TypedEndpointViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var status: DemoStatus = .idle

    func fetchList() async {
        status = .loading
        do {
            posts = try await NexioClient.shared.request(PostsEndpoint())
            status = .success("request(PostsEndpoint()) → \(posts.count) posts")
        } catch {
            status = .failure(describe(error))
        }
    }

    func fetchSingle() async {
        status = .loading
        do {
            let post: Post = try await NexioClient.shared.request(PostByIDEndpoint(id: 7))
            posts = [post]
            status = .success("request(PostByIDEndpoint(id: 7)) → #\(post.id)")
        } catch {
            status = .failure(describe(error))
        }
    }

    func create() async {
        status = .loading
        do {
            let endpoint = CreatePostEndpoint(
                post: NewPost(userId: 1, title: "Made via an Endpoint", body: "Type-safe POST through CreatePostEndpoint")
            )
            let created: Post = try await NexioClient.shared.request(endpoint)
            posts = [created]
            status = .success("request(CreatePostEndpoint(...)) → created #\(created.id)")
        } catch {
            status = .failure(describe(error))
        }
    }
}
