import SwiftUI
import Nexio

/// Root screen — a menu of demos. Configures the shared `NexioClient` once,
/// then lets each demo exercise a different corner of the SDK against
/// public test APIs (no keys required).
struct ContentView: View {

    @State private var didConfigure = false

    var body: some View {
        NavigationStack {
            List(DemoSection.allCases) { section in
                NavigationLink(value: section) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(section.rawValue).font(.headline)
                            Text(section.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: section.systemImage)
                            .foregroundStyle(.blue)
                    }
                }
            }
            .navigationTitle("Nexio Examples")
            .navigationDestination(for: DemoSection.self) { $0.destination }
        }
        .task {
            guard !didConfigure else { return }
            didConfigure = true
            await configureNexio()
        }
    }

    /// One-time setup, equivalent to what you'd do at app launch in a real app.
    private func configureNexio() async {
        var config = NexioConfig()
        config.baseURL = URL(string: "https://jsonplaceholder.typicode.com")
        config.timeout = 20
        config.logLevel = .all
        await NexioClient.shared.configure(config)

        // NOTE: setting `config.retry` alone does not enable retries yet —
        // register the interceptor explicitly to see retry behaviour in action.
        await NexioClient.shared.addInterceptor(RetryInterceptor(policy: .standard))
        await NexioClient.shared.addInterceptor(ConsoleLogInterceptor())
        await NexioClient.shared.addInterceptor(HeaderCaptureInterceptor())
    }
}

#Preview {
    ContentView()
}
