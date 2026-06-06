import SwiftUI
import Nexio

enum ErrorScenario: CaseIterable, Identifiable {
    case invalidURL, notFound, unauthorized, serverError, decodingFailed

    var id: Self { self }

    var title: String {
        switch self {
        case .invalidURL:     "Malformed URL string"
        case .notFound:       "404 on a real API"
        case .unauthorized:   "401 from a status-code sandbox"
        case .serverError:    "500 from a status-code sandbox"
        case .decodingFailed: "Response shape ≠ expected type"
        }
    }

    var expectedCase: String {
        switch self {
        case .invalidURL:     "→ NexioError.invalidURL"
        case .notFound:       "→ NexioError.notFound"
        case .unauthorized:   "→ NexioError.unauthorized"
        case .serverError:    "→ NexioError.serverError (after 3 retries, ~7s)"
        case .decodingFailed: "→ NexioError.decodingFailed"
        }
    }
}

@MainActor
final class ErrorHandlingViewModel: ObservableObject {
    @Published var status: DemoStatus = .idle
    @Published var caughtCase: String?

    func trigger(_ scenario: ErrorScenario) async {
        status = .loading
        caughtCase = nil

        struct AnyJSON: Decodable, Sendable {}
        struct OverlyStrictPost: Decodable, Sendable {
            let id: Int
            let aFieldThatDoesNotExistInThisAPI: Int
        }

        do {
            switch scenario {
            case .invalidURL:
                // A client with *no* baseURL can't fall back to relative
                // resolution, so an unparseable string surfaces .invalidURL —
                // exactly what NexioClientTests.getThrowsInvalidURL exercises.
                let bare = NexioClient()
                await bare.configure(NexioConfig())
                let _: AnyJSON = try await bare.get("not a url at all ://")

            case .notFound:
                let _: AnyJSON = try await NexioClient.shared.get("/posts/999999999")

            case .unauthorized:
                let _: AnyJSON = try await NexioClient.shared.get("https://httpstat.us/401")

            case .serverError:
                let _: AnyJSON = try await NexioClient.shared.get("https://httpstat.us/500")

            case .decodingFailed:
                let _: OverlyStrictPost = try await NexioClient.shared.get("/posts/1")
            }
            status = .failure("Expected an error here, but the request actually succeeded.")
        } catch let error as NexioError {
            caughtCase = "NexioError.\(caseName(error))"
            status = .success(error.errorDescription ?? "Caught \(caseName(error))")
        } catch {
            status = .failure(error.localizedDescription)
        }
    }

    private func caseName(_ error: NexioError) -> String {
        switch error {
        case .invalidURL:     "invalidURL"
        case .noInternet:     "noInternet"
        case .timeout:        "timeout"
        case .unauthorized:   "unauthorized"
        case .notFound:       "notFound"
        case .serverError:    "serverError"
        case .decodingFailed: "decodingFailed"
        case .unknown:        "unknown"
        }
    }
}
