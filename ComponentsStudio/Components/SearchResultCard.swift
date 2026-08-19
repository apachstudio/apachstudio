import SwiftUI

/// App-Store-style photo card. Fills its container's width and derives
/// height from a fixed 1:1.44 aspect ratio. The bottom strip uses the
/// shared `PlaceMetadataCard` (compact scale) so the card and the
/// full-screen detail sheet share one design language - same chips,
/// same tokens, same glass.
struct SearchResultCard: View {
    let place: Place

    /// Portrait aspect (width : height = 1 : 1.44).
    static let aspectRatio: CGFloat = 1.0 / 1.44
    static let cornerRadius: CGFloat = 32

    var body: some View {
        ZStack(alignment: .bottom) {
            RemoteImage(url: place.imageURL)

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.45),
                    .init(color: .black.opacity(0.32), location: 1.0),
                ],
                startPoint: .top, endPoint: .bottom
            )

            // Metadata strip inside the photo tile. Uses `.expanded`
            // (same spec as the place sheet's strip) so the result
            // card and the full-screen detail read with the exact
            // same chip sizes, paddings and corner radius — one
            // design across the two surfaces.
            PlaceMetadataCard(
                place: place,
                badge: .none,
                scale: .expanded
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(Self.aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                .stroke(Color.primary.opacity(0.04), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.10), radius: 6,  x: 0, y: 3)
        .shadow(color: .black.opacity(0.12), radius: 26, x: 0, y: 14)
    }
}
