import SwiftUI

/// Shared "what just happened" indicator used by every demo screen.
enum DemoStatus: Equatable {
    case idle
    case loading
    case success(String)
    case failure(String)
}

struct StatusBanner: View {
    let status: DemoStatus

    var body: some View {
        switch status {
        case .idle:
            EmptyView()
        case .loading:
            Label("Working…", systemImage: "arrow.triangle.2.circlepath")
                .foregroundStyle(.secondary)
        case .success(let message):
            Label(message, systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failure(let message):
            Label(message, systemImage: "xmark.octagon.fill")
                .foregroundStyle(.red)
        }
    }
}
