import Testing
import Foundation
@testable import Nexio

@Suite("ImageLoader")
struct ImageLoaderTests {

    // MARK: - Successful Load

    @Test("Loads image from valid PNG data")
    func loadsValidImage() async throws {
        let pngData = try #require(makePNGData(), "Could not create test PNG")
        MockURLProtocol.stub(statusCode: 200, data: pngData)
        URLProtocol.registerClass(MockURLProtocol.self)

        let loader = ImageLoader(session: .mock)
        let url = try #require(URL(string: "https://cdn.test/image.png"))

        let image = try await loader.load(url)
        #expect(image.size.width > 0)
    }

    // MARK: - Error Handling

    @Test("Throws .serverError on 404")
    func throwsOnNotFound() async throws {
        MockURLProtocol.stub(statusCode: 404, data: Data())
        URLProtocol.registerClass(MockURLProtocol.self)

        let loader = ImageLoader(session: .mock)
        let url = try #require(URL(string: "https://cdn.test/missing.png"))

        await #expect(throws: NexioError.self) {
            _ = try await loader.load(url)
        }
    }

    @Test("Throws .decodingFailed when data is not a valid image")
    func throwsOnInvalidImageData() async throws {
        MockURLProtocol.stub(statusCode: 200, data: Data("not an image".utf8))
        URLProtocol.registerClass(MockURLProtocol.self)

        let loader = ImageLoader(session: .mock)
        let url = try #require(URL(string: "https://cdn.test/bad.png"))

        do {
            _ = try await loader.load(url)
            Issue.record("Expected decodingFailed")
        } catch NexioError.decodingFailed {
            // expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    // MARK: - Cache

    @Test("clearCache does not throw")
    func clearCacheDoesNotThrow() async {
        let loader = ImageLoader(session: .mock)
        await loader.clearCache() // should complete without error
    }

    // MARK: - Prefetch

    @Test("prefetch silently discards errors")
    func prefetchIgnoresErrors() async throws {
        // No stub — will hit noInternet
        MockURLProtocol.reset()
        URLProtocol.registerClass(MockURLProtocol.self)

        let loader = ImageLoader(session: .mock)
        let urls = (1...3).compactMap { URL(string: "https://cdn.test/img\($0).png") }
        // Must complete without throwing
        await loader.prefetch(urls)
    }
}

// MARK: - Helpers

/// Creates a 1×1 red PNG for use in image tests.
private func makePNGData() -> Data? {
#if canImport(UIKit)
    import UIKit
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
    return renderer.pngData { ctx in
        UIColor.red.setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
    }
#elseif canImport(AppKit)
    import AppKit
    let image = NSImage(size: NSSize(width: 1, height: 1))
    image.lockFocus()
    NSColor.red.set()
    NSRect(x: 0, y: 0, width: 1, height: 1).fill()
    image.unlockFocus()
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
    return bitmap.representation(using: .png, properties: [:])
#else
    return nil
#endif
}
