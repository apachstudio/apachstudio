import SwiftUI

/// A single nature card in the cloud. Same 1:1.44 ratio as the search result
/// cards, with a deterministic rotation that makes the cloud feel like cards
/// scattered on a canvas. Subtle two-pass shadow gives soft elevation.
///
/// The parent applies position, scale, and opacity every frame (fisheye +
/// breathing + entrance); this view just draws.
struct BubbleView: View {
    let place: Place
    /// Logical height (max dimension). The width is derived from the aspect.
    let size: CGFloat
    /// Rotation in degrees — kept stable per cell.
    var rotation: Double = 0

    private var width: CGFloat { size / Cloud.bubbleAspect }

    /// Food bubbles fall back to a fork-and-knife glyph; everything else
    /// to the generic photo glyph — so a failed load still reads as the
    /// right kind of content.
    private var fallbackSymbol: String {
        place.category.lowercased() == "food" ? "fork.knife" : "photo"
    }

    var body: some View {
        RemoteImage(url: place.imageURL, fallbackSymbol: fallbackSymbol)
            .frame(width: width, height: size)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
            )
            // Soft, smooth two-pass elevation: tight contact + wide ambient.
            // Both are low-opacity so the cloud stays light, not heavy.
            .shadow(color: .black.opacity(0.06), radius: 4,  x: 0, y: 2)
            .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 10)
            .rotationEffect(.degrees(rotation))
    }
}
