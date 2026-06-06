import Foundation

/// Matches `https://jsonplaceholder.typicode.com/posts/{id}`.
struct Post: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let userId: Int
    let title: String
    let body: String
}

/// Body shape for POST/PUT — the API echoes it back wrapped in a `Post`.
struct NewPost: Encodable, Sendable {
    let userId: Int
    let title: String
    let body: String
}
