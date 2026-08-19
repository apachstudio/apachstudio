import SwiftUI

/// Unified metadata card used by BOTH the search result card and the
/// detail sheet — same Liquid Glass surface, same text tokens, same
/// chip row. Different SLOTS for context: search results get a "% match"
/// badge in the top trailing corner; the detail sheet gets a footer
/// CTA pill instead. Sizing scales via `Scale`, so the same component
/// reads as a compact strip inside a result card and as a full
/// metadata block on the sheet.
struct PlaceMetadataCard: View {
    // MARK: - Inputs

    let place: Place
    let badge: TrailingBadge
    let scale: Scale

    enum Scale {
        /// Result card variant — smaller fonts and padding.
        case compact
        /// Detail sheet variant — larger title, looser padding.
        case expanded
    }

    enum TrailingBadge: Equatable {
        case none
        /// AI match percentage chip — shown on the search result card.
        case matchPercent(Int)
    }

    // MARK: - Scale tokens

    private var titlePointSize: CGFloat { scale == .expanded ? 18 : 12 }
    private var subtitlePointSize: CGFloat { scale == .expanded ? 13 : 12 }
    private var chipTextSize: CGFloat { scale == .expanded ? 12 : 11 }
    private var chipIconSize: CGFloat { scale == .expanded ? 10 : 9 }
    private var horizontalPadding: CGFloat { scale == .expanded ? 22 : 14 }
    private var verticalPadding: CGFloat { scale == .expanded ? 22 : 14 }
    private var cornerRadius: CGFloat { scale == .expanded ? 36 : 26 }
    private var sectionSpacing: CGFloat { scale == .expanded ? 18 : 12 }
    private var titleBlockSpacing: CGFloat { scale == .expanded ? 8 : 4 }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            ZStack(alignment: .topTrailing) {
                titleBlock
                    .frame(maxWidth: .infinity, alignment: .leading)
                if case .matchPercent(let pct) = badge {
                    matchChip(pct: pct)
                }
            }
            metaChips
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background {
            // Same `.clear.tint(Aurora.ink @ 82%)` Liquid Glass spec
            // as the CTA pill below — all metadata surfaces (card,
            // chips, CTA) share the dark frosted treatment so they
            // read as one consistent component, not stacked layers.
            if #available(iOS 26.0, *) {
                Color.clear.glassEffect(
                    .clear.tint(Aurora.ink.opacity(0.62)),
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Aurora.ink.opacity(0.62))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.02), lineWidth: 0.5)
        )
        .shadow(
            color: PlaceCardShadow.color(scale: scale),
            radius: PlaceCardShadow.radius(scale: scale),
            x: 0,
            y: PlaceCardShadow.y(scale: scale)
        )
    }

    // MARK: - Title block

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: titleBlockSpacing) {
            Text(place.title)
                .font(AppFont.manrope(titlePointSize, .light, relativeTo: .title))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            Text(place.subtitle)
                .font(AppFont.manrope(subtitlePointSize, .medium, relativeTo: .subheadline))
                .foregroundStyle(Color.white.opacity(0.7))
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Meta chips (shared row)

    private var metaChips: some View {
        HStack(spacing: 8) {
            metaChip(icon: "bed.double.fill", text: "\(place.stays) stays")
            metaChip(icon: "star.fill", text: String(format: "%.1f", place.rating))
            metaChip(icon: "leaf.fill", text: place.category)
        }
    }

    private func metaChip(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: chipIconSize, weight: .semibold))
                .accessibilityHidden(true)
            Text(text)
                .font(AppFont.manrope(chipTextSize, .semibold, relativeTo: .caption))
                .tracking(0.3)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background {
            if #available(iOS 26.0, *) {
                Color.clear.glassEffect(
                    .clear.tint(Aurora.ink.opacity(0.02)),
                    in: Capsule()
                )
            } else {
                Capsule().fill(Aurora.ink.opacity(0.02))
            }
        }
        .overlay(Capsule().stroke(Color.white.opacity(0.00), lineWidth: 0.0))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Match badge (trailing slot, compact only)

    private func matchChip(pct: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.system(size: 10, weight: .bold))
                .accessibilityHidden(true)
            Text("\(pct)%")
                .font(AppFont.manrope(11, .semibold, relativeTo: .caption2))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(Aurora.accent))
        .shadow(color: .black.opacity(0.20), radius: 8, y: 2)
        .accessibilityLabel("\(pct) percent match")
    }

}

// MARK: - Shared shadow tokens

/// Shadow values shared by `PlaceMetadataCard` and `PlaceExploreCTA`
/// so the two sibling surfaces lift off the background with the same
/// physical-light read. Scale matches the metadata card's scale.
enum PlaceCardShadow {
    static func color(scale: PlaceMetadataCard.Scale) -> Color {
        .black.opacity(scale == .expanded ? 0.34 : 0.18)
    }
    static func radius(scale: PlaceMetadataCard.Scale) -> CGFloat {
        scale == .expanded ? 32 : 14
    }
    static func y(scale: PlaceMetadataCard.Scale) -> CGFloat {
        scale == .expanded ? 14 : 6
    }
}

// MARK: - PlaceExploreCTA

/// Standalone CTA pill that lives BELOW the metadata card as a sibling
/// (not a footer slot). Pure iOS 26 Liquid Glass via the system's
/// `.buttonStyle(.glassProminent)` — no custom backgrounds, gradients
/// or inner accents. Apple handles luminance, touch reactivity, and
/// the prominent surface. `action: nil` makes the pill non-interactive
/// (used inside the result card, which is already wrapped in a parent
/// Button — disabling hit testing here keeps the outer tap as the
/// single source of truth).
struct PlaceExploreCTA: View {
    let title: String
    let action: (() -> Void)?
    let scale: PlaceMetadataCard.Scale

    // MARK: - Sizing

    /// CTA pill uses the SAME corner radius as the metadata card so the
    /// two sibling surfaces read as one design separated by the seam,
    /// not a capsule glued under a rounded rect.
    private var ctaCornerRadius: CGFloat { scale == .expanded ? 36 : 26 }
    private var ctaHeight: CGFloat       { scale == .expanded ? 56 : 48 }
    private var ctaHorizontalPad: CGFloat { scale == .expanded ? 22 : 18 }
    private var ctaTextSize: CGFloat     { scale == .expanded ? 15 : 13 }
    private var ctaIconSize: CGFloat     { scale == .expanded ? 14 : 12 }

    var body: some View {
        Group {
            if let action {
                Button(action: action) { pill }
                    .buttonStyle(.plain)
            } else {
                pill
                    .accessibilityAddTraits(.isButton)
            }
        }
        .accessibilityLabel(title)
    }

    private var pill: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(AppFont.manrope(ctaTextSize, .semibold, relativeTo: .subheadline))
            Spacer(minLength: 0)
            Image(systemName: "arrow.right")
                .font(.system(size: ctaIconSize, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, ctaHorizontalPad)
        .frame(height: ctaHeight)
        .frame(maxWidth: .infinity)
        .background {
            ctaBackground
        }
        .overlay(
            RoundedRectangle(cornerRadius: ctaCornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.02), lineWidth: 0.5)
        )
        .shadow(
            color: PlaceCardShadow.color(scale: scale),
            radius: PlaceCardShadow.radius(scale: scale),
            x: 0,
            y: PlaceCardShadow.y(scale: scale)
        )
    }

    /// Dark CTA surface — uses Apple's `.clear` Glass variant (more
    /// transparent than `.regular`) tinted with `Aurora.ink @ 82%`. The
    /// photo behind refracts through more vividly while the ink tint
    /// still anchors the CTA as a dark "press here" pill. Solid
    /// `Aurora.ink` fallback on older OSes.
    @ViewBuilder
    private var ctaBackground: some View {
        if #available(iOS 26.0, *) {
            Color.clear.glassEffect(
                .clear.tint(Aurora.ink.opacity(0.82)),
                in: RoundedRectangle(cornerRadius: ctaCornerRadius, style: .continuous)
            )
        } else {
            RoundedRectangle(cornerRadius: ctaCornerRadius, style: .continuous)
                .fill(Aurora.ink)
        }
    }
}

// MARK: - Shared glass background helper (file-private)

/// Native iOS 26 Liquid Glass in the supplied shape — uses the
/// `.clear` variant so surfaces stay maximally transparent and the
/// photo / canvas behind refracts through. `.ultraThinMaterial`
/// fallback for older OSes.
@ViewBuilder
fileprivate func glassBackground<S: Shape>(in shape: S) -> some View {
    if #available(iOS 26.0, *) {
        Color.clear.glassEffect(.clear, in: shape)
    } else {
        shape.fill(.ultraThinMaterial)
    }
}
