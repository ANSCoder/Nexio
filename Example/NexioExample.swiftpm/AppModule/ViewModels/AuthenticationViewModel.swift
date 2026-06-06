import SwiftUI
import Nexio

enum AuthAction: CaseIterable, Identifiable {
    case bearer, apiKey, custom, dynamicInterceptor, endpointOverride

    var id: Self { self }

    var title: String {
        switch self {
        case .bearer:             "setAuth(.bearer(\u{201C}token\u{201D}))"
        case .apiKey:             "setAuth(.apiKey(header:value:))"
        case .custom:             "setAuth(.custom([...]))"
        case .dynamicInterceptor: "AuthInterceptor { await refreshedToken() }"
        case .endpointOverride:   "Endpoint.auth overrides the global strategy"
        }
    }

    var subtitle: String {
        switch self {
        case .bearer:             "Adds Authorization: Bearer <token> globally"
        case .apiKey:             "Adds a static X-Api-Key header globally"
        case .custom:             "Injects an arbitrary header set globally"
        case .dynamicInterceptor: "Calls an async provider before every request"
        case .endpointOverride:   "Per-endpoint auth wins over NexioClient.setAuth"
        }
    }
}

@MainActor
final class AuthenticationViewModel: ObservableObject {
    @Published var capturedHeaders: [String: String] = [:]
    @Published var status: DemoStatus = .idle

    private var dynamicTokenSeed = 0

    func run(_ action: AuthAction) async {
        status = .loading
        do {
            switch action {
            case .bearer:
                await NexioClient.shared.setAuth(.bearer("static-jwt-token"))
                let _: Post = try await NexioClient.shared.get("/posts/1")

            case .apiKey:
                await NexioClient.shared.setAuth(.apiKey(header: "X-Api-Key", value: "secret-api-key"))
                let _: Post = try await NexioClient.shared.get("/posts/1")

            case .custom:
                await NexioClient.shared.setAuth(.custom([
                    "X-Client": "NexioExample",
                    "X-Session": UUID().uuidString
                ]))
                let _: Post = try await NexioClient.shared.get("/posts/1")

            case .dynamicInterceptor:
                // Static auth off; a fresh token is minted by the provider
                // closure on every single request — useful for OAuth refresh.
                await NexioClient.shared.setAuth(.none)
                dynamicTokenSeed += 1
                let token = "refreshed-token-\(dynamicTokenSeed)"
                await NexioClient.shared.addInterceptor(AuthInterceptor { .bearer(token) })
                let _: Post = try await NexioClient.shared.get("/posts/1")

            case .endpointOverride:
                await NexioClient.shared.setAuth(.bearer("global-bearer-token"))
                let _: Post = try await NexioClient.shared.request(EndpointAuthOverrideEndpoint(id: 1))
            }

            capturedHeaders = await LastRequestHeadersStore.shared.headers
            status = .success("\(action.title) → inspect the headers that actually went on the wire below")
        } catch {
            status = .failure(describe(error))
        }
    }
}
