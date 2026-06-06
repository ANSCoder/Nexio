import SwiftUI

struct GetRequestView: View {
    @StateObject private var viewModel = GetRequestViewModel()

    var body: some View {
        List {
            Section("NexioClient.shared.get(_:)") {
                Button("Fetch array — GET /posts?_limit=10") {
                    Task { await viewModel.loadList() }
                }
                Button("Fetch single object — GET /posts/1") {
                    Task { await viewModel.loadSingle(id: 1) }
                }
                StatusBanner(status: viewModel.status)
            }
            if !viewModel.posts.isEmpty {
                Section("Decoded `[Post]` / `Post`") {
                    ForEach(viewModel.posts) { post in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("#\(post.id) — \(post.title)")
                                .font(.headline)
                                .lineLimit(2)
                            Text(post.body)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("GET Requests")
    }
}
