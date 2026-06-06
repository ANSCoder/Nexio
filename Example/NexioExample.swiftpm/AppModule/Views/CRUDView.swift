import SwiftUI

struct CRUDView: View {
    @StateObject private var viewModel = CRUDViewModel()

    var body: some View {
        Form {
            Section("Request body") {
                TextField("Title", text: $viewModel.title)
                TextField("Body", text: $viewModel.body, axis: .vertical)
                    .lineLimit(2...4)
            }
            Section("Mutating requests") {
                Button("POST → create") { Task { await viewModel.create() } }
                Button("PUT → replace post #1") { Task { await viewModel.replace() } }
                Button("PATCH → patch post #1's title") { Task { await viewModel.patchTitle() } }
                Button("DELETE → remove post #1", role: .destructive) {
                    Task { await viewModel.delete() }
                }
            }
            Section {
                StatusBanner(status: viewModel.status)
                if let post = viewModel.lastResult {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("#\(post.id) — \(post.title)").font(.subheadline.bold())
                        Text(post.body).font(.caption).foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Result")
            } footer: {
                Text("jsonplaceholder.typicode.com is a fake REST API — it echoes back what you send without persisting it.")
            }
        }
        .navigationTitle("Create / Update / Delete")
    }
}
