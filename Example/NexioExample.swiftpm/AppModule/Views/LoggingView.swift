import SwiftUI

struct LoggingView: View {
    @StateObject private var viewModel = LoggingViewModel()

    var body: some View {
        List {
            Section("Custom Interceptor (see Support/Interceptors.swift)") {
                Text("ConsoleLogInterceptor implements `Interceptor.adapt`/`retry` and writes a trace to an actor-backed store — the same seam `AuthInterceptor` and `RetryInterceptor` use internally. `NexioConfig.logLevel = .all` mirrors this to the Xcode console too.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Fire a sample GET request") {
                    Task { await viewModel.fireSampleRequest() }
                }
                StatusBanner(status: viewModel.status)
            }
            Section("Trace") {
                if viewModel.lines.isEmpty {
                    Text("No requests captured yet — fire one above, or browse to any other demo.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(viewModel.lines.enumerated()), id: \.offset) { _, line in
                        Text(line).font(.system(.footnote, design: .monospaced))
                    }
                }
            }
        }
        .navigationTitle("Interceptors & Logging")
        .toolbar {
            Button("Clear") { Task { await viewModel.clear() } }
        }
        .task { await viewModel.refresh() }
    }
}
