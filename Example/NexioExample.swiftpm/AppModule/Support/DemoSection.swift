import SwiftUI

/// Each case is one demo screen — the menu structure for the app.
enum DemoSection: String, CaseIterable, Identifiable, Hashable {
    case getRequests    = "GET Requests"
    case crud           = "POST / PUT / PATCH / DELETE"
    case typedEndpoint  = "Type-Safe Endpoints"
    case authentication = "Authentication"
    case retry          = "Retry & Backoff"
    case imageGallery   = "Image Loading (NexioImage)"
    case logging        = "Interceptors & Logging"
    case errorHandling  = "Error Handling"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .getRequests:    "Decode JSON arrays & single objects"
        case .crud:           "Create, replace, patch, and delete resources"
        case .typedEndpoint:  "Group requests behind an Endpoint"
        case .authentication: "Bearer, API key, custom & dynamic auth"
        case .retry:          "Exponential backoff on transient failures"
        case .imageGallery:   "Cached, prefetchable remote images"
        case .logging:        "Inspect requests via Interceptor + LogLevel"
        case .errorHandling:  "Every NexioError case, end to end"
        }
    }

    var systemImage: String {
        switch self {
        case .getRequests:    "arrow.down.circle"
        case .crud:           "pencil.and.list.clipboard"
        case .typedEndpoint:  "shippingbox"
        case .authentication: "key.fill"
        case .retry:          "arrow.clockwise.circle"
        case .imageGallery:   "photo.on.rectangle.angled"
        case .logging:        "doc.text.magnifyingglass"
        case .errorHandling:  "exclamationmark.triangle"
        }
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .getRequests:    GetRequestView()
        case .crud:           CRUDView()
        case .typedEndpoint:  TypedEndpointView()
        case .authentication: AuthenticationView()
        case .retry:          RetryView()
        case .imageGallery:   ImageGalleryView()
        case .logging:        LoggingView()
        case .errorHandling:  ErrorHandlingView()
        }
    }
}
