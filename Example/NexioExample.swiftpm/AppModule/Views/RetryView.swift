import SwiftUI

struct RetryView: View {
    @StateObject private var viewModel = RetryViewModel()

    var body: some View {
        List {
            Section("RetryInterceptor(policy: .standard) — 3 attempts, exponential backoff") {
                Button("Hit /503 — retried (5xx is retryable, ~7s total)") {
                    Task { await viewModel.trigger(statusCode: 503) }
                }
                Button("Hit /404 — not retried (only noInternet/timeout/5xx are)") {
                    Task { await viewModel.trigger(statusCode: 404) }
                }
                StatusBanner(status: viewModel.status)
            }
            Section("Attempt trace (via Interceptor.retry hook)") {
                if viewModel.attemptLog.isEmpty {
                    Text("Trigger a request above to see each retry logged here.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(viewModel.attemptLog.enumerated()), id: \.offset) { _, line in
                        Text(line).font(.system(.footnote, design: .monospaced))
                    }
                }
            }
        }
        .navigationTitle("Retry & Backoff")
    }
}
