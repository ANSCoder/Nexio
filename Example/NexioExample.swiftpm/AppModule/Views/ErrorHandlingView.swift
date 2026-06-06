import SwiftUI

struct ErrorHandlingView: View {
    @StateObject private var viewModel = ErrorHandlingViewModel()

    var body: some View {
        List {
            Section("Trigger every NexioError case") {
                ForEach(ErrorScenario.allCases) { scenario in
                    Button {
                        Task { await viewModel.trigger(scenario) }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(scenario.title)
                            Text(scenario.expectedCase)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section("Caught") {
                StatusBanner(status: viewModel.status)
                if let caughtCase = viewModel.caughtCase {
                    Text(caughtCase)
                        .font(.system(.body, design: .monospaced).bold())
                        .foregroundStyle(.blue)
                }
            }
        }
        .navigationTitle("Error Handling")
    }
}
