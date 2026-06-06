#if canImport(SwiftUI)
import SwiftUI

// MARK: - NexioImage

/// A SwiftUI view that loads and caches a remote image.
///
/// Drop-in replacement for `AsyncImage` with built-in caching, a configurable
/// placeholder, an optional failure image, and a fade-in transition.
///
/// ```swift
/// NexioImage("https://cdn.example.com/photo.jpg")
///     .frame(width: 100, height: 100)
///     .clipShape(Circle())
/// ```
public struct NexioImage<Placeholder: View, Failure: View>: View {

    // MARK: - State

    @State private var phase: LoadPhase = .loading

    // MARK: - Config

    private let url: String
    private let contentMode: ContentMode
    private let placeholder: Placeholder
    private let failureImage: Failure
    private let transition: AnyTransition
    private let loader: ImageLoader

    // MARK: - Init

    /// Creates a `NexioImage` with custom placeholder and failure views.
    ///
    /// - Parameters:
    ///   - url: Remote image URL string.
    ///   - contentMode: How the image fills its frame. Defaults to `.fill`.
    ///   - placeholder: View shown while loading.
    ///   - failureImage: View shown when loading fails.
    ///   - transition: Transition applied when the image appears. Defaults to `.opacity`.
    ///   - loader: Image loader instance. Defaults to ``ImageLoader/shared``.
    public init(
        _ url: String,
        contentMode: ContentMode = .fill,
        @ViewBuilder placeholder: () -> Placeholder,
        @ViewBuilder failureImage: () -> Failure,
        transition: AnyTransition = .opacity,
        loader: ImageLoader = .shared
    ) {
        self.url = url
        self.contentMode = contentMode
        self.placeholder = placeholder()
        self.failureImage = failureImage()
        self.transition = transition
        self.loader = loader
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            switch phase {
            case .loading:
                placeholder
            case .loaded(let image):
                Image(platformImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(transition)
            case .failed:
                failureImage
            }
        }
        .animation(.easeInOut(duration: 0.25), value: phase.isLoaded)
        .task(id: url) {
            await loadImage()
        }
        .accessibilityLabel("Image from \(url)")
    }

    // MARK: - Private

    private func loadImage() async {
        phase = .loading
        guard let imageURL = URL(string: url) else {
            phase = .failed
            return
        }
        do {
            let image = try await loader.load(imageURL)
            phase = .loaded(image)
        } catch {
            phase = .failed
        }
    }
}

// MARK: - Convenience init with default views

extension NexioImage where Placeholder == Color, Failure == Image {

    /// Creates a `NexioImage` with a gray placeholder and system photo icon on failure.
    ///
    /// - Parameters:
    ///   - url: Remote image URL string.
    ///   - contentMode: How the image fills its frame. Defaults to `.fill`.
    ///   - transition: Transition applied when the image appears.
    public init(
        _ url: String,
        contentMode: ContentMode = .fill,
        transition: AnyTransition = .opacity
    ) {
        self.init(
            url,
            contentMode: contentMode,
            placeholder: { Color(.systemGray5) },
            failureImage: { Image(systemName: "photo") },
            transition: transition
        )
    }
}

// MARK: - LoadPhase

private enum LoadPhase: Equatable {
    case loading
    case loaded(PlatformImage)
    case failed

    var isLoaded: Bool {
        if case .loaded = self { return true }
        return false
    }

    static func == (lhs: LoadPhase, rhs: LoadPhase) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading), (.failed, .failed):
            return true
        case (.loaded(let a), .loaded(let b)):
            return a === b
        default:
            return false
        }
    }
}

// MARK: - Image cross-platform helper

private extension Image {
    init(platformImage: PlatformImage) {
#if canImport(UIKit)
        self.init(uiImage: platformImage)
#elseif canImport(AppKit)
        self.init(nsImage: platformImage)
#endif
    }
}

#endif // canImport(SwiftUI)
