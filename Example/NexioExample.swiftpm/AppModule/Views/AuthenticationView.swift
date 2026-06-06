import SwiftUI

struct AuthenticationView: View {
    @StateObject private var viewModel = AuthenticationViewModel()

    var body: some View {
        List {
            Section("AuthStrategy / AuthInterceptor / Endpoint.auth") {
                ForEach(AuthAction.allCases) { action in
                    Button {
                        Task { await viewModel.run(action) }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(action.title).font(.system(.body, design: .monospaced))
                            Text(action.subtitle).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                StatusBanner(status: viewModel.status)
            }
            Section("Headers captured on the wire (HeaderCaptureInterceptor)") {
                if viewModel.capturedHeaders.isEmpty {
                    Text("Run a strategy above to inspect the outgoing request.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.capturedHeaders.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        HStack(alignment: .firstTextBaseline) {
                            Text(key)
                                .font(.system(.footnote, design: .monospaced).bold())
                            Spacer()
                            Text(value)
                                .font(.system(.footnote, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
            }
        }
        .navigationTitle("Authentication")
    }
}
