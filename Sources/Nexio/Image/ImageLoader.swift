// Copyright (c) 2026 ANSCoder
// Licensed under the MIT License. See LICENSE in the project root for details.

import Foundation

#if canImport(UIKit)
import UIKit
/// Platform-native image type. `UIImage` on iOS, tvOS, watchOS.
public typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
/// Platform-native image type. `NSImage` on macOS.
public typealias PlatformImage = NSImage

// `NSImage` predates Swift concurrency and isn't `Sendable`, but Nexio only
// ever hands instances across actor boundaries as immutable, already-decoded
// snapshots — never mutates them after `load(_:)` returns.
extension NSImage: @retroactive @unchecked Sendable {}
#endif

/// Carries a decoded image out of a detached task. Images are decoded once and
/// never mutated afterwards, so sharing the reference is safe.
private struct DecodedImage: @unchecked Sendable {
    let image: PlatformImage
}

// MARK: - ImageLoader

/// An actor that fetches and caches platform images.
///
/// Uses `URLCache` for transparent memory + disk caching — images are not
/// re-downloaded on repeat requests within the cache policy's lifetime.
///
/// ```swift
/// let image = try await ImageLoader.shared.load(url)
/// ```
public actor ImageLoader {

    // MARK: - Singleton

    /// Shared instance used by ``NexioImage``.
    public static let shared = ImageLoader()

    // MARK: - Constants

    /// Maximum number of images fetched at once by ``prefetch(_:)``.
    private static let prefetchConcurrency = 4

    // MARK: - Private State

    private let session: URLSession

    // MARK: - Init

    /// Creates an `ImageLoader` with an optional custom `URLSession`.
    ///
    /// The default session is configured with a 50 MB memory cache and a
    /// 200 MB disk cache, which is appropriate for most apps.
    ///
    /// - Parameter session: Override for testing. Pass `nil` to use the default.
    public init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let cache = URLCache(
                memoryCapacity: 50 * 1024 * 1024,   // 50 MB
                diskCapacity: 200 * 1024 * 1024,    // 200 MB
                diskPath: "com.nexio.imagecache"
            )
            let config = URLSessionConfiguration.default
            config.urlCache = cache
            config.requestCachePolicy = .returnCacheDataElseLoad
            self.session = URLSession(configuration: config)
        }
    }

    // MARK: - Public API

    /// Loads an image from `url`, returning a cached copy if available.
    ///
    /// - Parameter url: The image URL.
    /// - Returns: The decoded platform image.
    /// - Throws: ``NexioError`` on network failure; a generic error if the
    ///   data cannot be decoded as an image.
    public func load(_ url: URL) async throws -> PlatformImage {
        let request = URLRequest(url: url)
        let (data, response) = try await session.nexioData(for: request)
        if let httpError = response.nexioError(data: data) {
            throw httpError
        }
        try Task.checkCancellation()
        // Decoding is CPU work. decodeImage is nonisolated, so it runs off the actor.
        let decoded = await Self.decodeImage(data)
        try Task.checkCancellation()
        guard let decoded else {
            throw NexioError.decodingFailed(
                underlying: ImageDecodingError.invalidImageData,
                data: data
            )
        }
        return decoded.image
    }

    /// Prefetches images in the background, populating the `URLCache`.
    ///
    /// Errors are silently discarded — prefetch failures are non-fatal.
    ///
    /// - Parameter urls: URLs to warm up in the cache.
    public func prefetch(_ urls: [URL]) async {
        await withTaskGroup(of: Void.self) { group in
            var remaining = urls.makeIterator()
            // Keep at most `prefetchConcurrency` downloads in flight.
            for _ in 0..<min(Self.prefetchConcurrency, urls.count) {
                if let url = remaining.next() {
                    group.addTask { _ = try? await self.load(url) }
                }
            }
            while await group.next() != nil {
                if let url = remaining.next() {
                    group.addTask { _ = try? await self.load(url) }
                }
            }
        }
    }

    /// Decodes image bytes. Nonisolated, so it runs off the actor.
    private static func decodeImage(_ data: Data) async -> DecodedImage? {
        PlatformImage(data: data).map { DecodedImage(image: $0) }
    }

    /// Removes all cached images from memory and disk.
    public func clearCache() {
        session.configuration.urlCache?.removeAllCachedResponses()
    }
}

// MARK: - Private

private enum ImageDecodingError: Error {
    case invalidImageData
}
