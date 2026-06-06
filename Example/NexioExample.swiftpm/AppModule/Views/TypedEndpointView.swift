import SwiftUI

struct TypedEndpointView: View {
    @StateObject private var viewModel = TypedEndpointViewModel()

    var body: some View {
        List {
            Section("Endpoint conformers — see Models/Endpoints.swift") {
                Button("PostsEndpoint — GET /posts?_limit=10") {
                    Task { await viewModel.fetchList() }
                }
                Button("PostByIDEndpoint(id: 7) — GET /posts/7") {
                    Task { await viewModel.fetchSingle() }
                }
                Button("CreatePostEndpoint — POST /posts") {
                    Task { await viewModel.create() }
                }
                StatusBanner(status: viewModel.status)
            }
            if !viewModel.posts.isEmpty {
                Section("Decoded result") {
                    ForEach(viewModel.posts) { post in
                        Text("#\(post.id) — \(post.title)").lineLimit(1)
                    }
                }
            }
        }
        .navigationTitle("Type-Safe Endpoints")
    }
}
