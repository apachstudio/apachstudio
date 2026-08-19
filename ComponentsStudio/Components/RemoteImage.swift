import SwiftUI
import UIKit

/// Tiny in-memory image cache shared across bubbles + cards, so the cloud
/// (which re-renders every frame for breathing) never re-fetches and the hero /
/// card photos appear instantly once loaded.
final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()
    private let cache = NSCache<NSURL, UIImage>()

    func image(for url: URL) -> UIImage? { cache.object(forKey: url as NSURL) }
    func insert(_ image: UIImage, for url: URL) { cache.setObject(image, forKey: url as NSURL) }
}

@MainActor
final class ImageLoader: ObservableObject {
    /// Three explicit states so the view can ALWAYS render a non-empty
    /// visual: a placeholder while loading, the photo on success, and a
    /// fallback fill (never transparent) when every source fails.
    enum Phase {
        case loading
        case loaded(UIImage)
        case failed
    }

    @Published var phase: Phase = .loading

    func load(_ url: URL?) async {
        guard let url else {
            phase = .failed
            return
        }
        if let cached = ImageCache.shared.image(for: url) {
            phase = .loaded(cached)
            return
        }
        phase = .loading
        if let primary = try? await fetchValidImage(from: url) {
            ImageCache.shared.insert(primary, for: url)
            phase = .loaded(primary)
            return
        }
        // Primary failed — fall back to a guaranteed-working source so
        // no card ever ends up empty. We seed Picsum with the original
        // URL's hash so the SAME failing URL deterministically maps to
        // the same fallback photo across renders.
        if let fallback = picsumFallback(for: url),
           let img = try? await fetchValidImage(from: fallback) {
            // Cache under the ORIGINAL key so the fallback is reused
            // on every subsequent render of this Place.
            ImageCache.shared.insert(img, for: url)
            phase = .loaded(img)
            return
        }
        // Everything failed (offline, both hosts down) — surface the
        // symbol fallback instead of a blank slot.
        phase = .failed
    }

    /// Fetches `url` and returns the decoded image only when both the
    /// HTTP status is 2xx and the bytes decode to a `UIImage`. Anything
    /// else (4xx, 5xx, decode failure, network error) throws so the
    /// caller can fall back.
    private func fetchValidImage(from url: URL) async throws -> UIImage {
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse,
           !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        guard let img = UIImage(data: data) else {
            throw URLError(.cannotDecodeContentData)
        }
        return img
    }

    /// Deterministic Picsum fallback for a primary URL. Same input URL
    /// → same fallback photo (so a 404'd card doesn't shuffle its
    /// fallback every render). Picsum's free API serves real landscape
    /// photos at the requested size with zero auth.
    private func picsumFallback(for url: URL) -> URL? {
        let seed = abs(url.absoluteString.hashValue)
        return URL(string: "https://picsum.photos/seed/places-\(seed)/1200/1600")
    }
}

/// A cached remote image that fills its proposed frame without ever
/// dictating its own size. The photo lives in an `.overlay` over a
/// flexible `Color.clear`, so layout-driving modifiers on callers
/// (`.aspectRatio`, `.frame`) always win — otherwise a freshly-loaded
/// `Image.resizable().scaledToFill()` brings its pixel-intrinsic size
/// to the layout and, inside a vertical ScrollView with infinite
/// proposed height, inflates the parent to the photo's full size
/// (the "search-result card explodes to full-bleed when image loads"
/// bug). `.clipped()` keeps `scaledToFill`'s overflow inside the
/// frame; callers still own the shape clip for rounded corners.
struct RemoteImage: View {
    let url: URL?
    /// SF Symbol drawn on the failure fill so a broken/offline photo
    /// reads as an intentional placeholder, not a blank slot. Defaults
    /// to `photo`; food contexts can pass e.g. `fork.knife`.
    var fallbackSymbol: String = "photo"

    @StateObject private var loader = ImageLoader()

    init(url: URL?, fallbackSymbol: String = "photo") {
        self.url = url
        self.fallbackSymbol = fallbackSymbol
    }

    var body: some View {
        Color.clear
            .overlay {
                switch loader.phase {
                case .loaded(let img):
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                case .loading:
                    placeholder(showsProgress: true)
                case .failed:
                    placeholder(showsProgress: false)
                }
            }
            .clipped()
            .task(id: url) { await loader.load(url) }
    }

    /// A guaranteed-visible fill for the non-success phases. Always the
    /// `cardInk` photo-slot token plus a centered cue (spinner while
    /// loading, symbol on failure) so the view is never empty/transparent.
    @ViewBuilder
    private func placeholder(showsProgress: Bool) -> some View {
        ZStack {
            Aurora.cardInk
            if showsProgress {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Color.white.opacity(0.7))
            } else {
                Image(systemName: fallbackSymbol)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
        }
    }
}
