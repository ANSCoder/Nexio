import SwiftUI
import Nexio

/// Stateless — `NexioImage` and `ImageLoader` already manage their own
/// loading/caching state, so there's no view model to extract here.
struct ImageGalleryView: View {

    private let photoIDs = Array(1...24)
    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(photoIDs, id: \.self) { id in
                    NexioImage(imageURL(for: id))
                        .frame(height: 110)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .padding()
        }
        .navigationTitle("NexioImage")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Prefetch") {
                    Task {
                        let urls = photoIDs.compactMap { URL(string: imageURL(for: $0)) }
                        await ImageLoader.shared.prefetch(urls)
                    }
                }
                Button("Clear cache") {
                    Task { await ImageLoader.shared.clearCache() }
                }
            }
        }
    }

    /// Lorem Picsum — public placeholder-image service, stable per-ID URLs so
    /// `URLCache`/`ImageLoader` caching is easy to observe (re-open this
    /// screen and the grid repaints instantly from cache).
    private func imageURL(for id: Int) -> String {
        "https://picsum.photos/id/\(id)/300/300"
    }
}
