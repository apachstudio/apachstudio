import SwiftUI

/// Vertical card deck — a snap-paged, scroll-driven stack of place cards.
/// One focused card sits centred and large; the previous card peeks at the
/// top and the next peeks at the bottom (smaller + dimmed). Swipe up/down
/// to move through them.
///
/// Reuses the same `[Place]` array the bubble cloud reads, and reuses the
/// existing `PlaceSheetView` morph for tap-to-detail: a tapped card's
/// global frame is reported back so the hero photo can scale out of that
/// exact rect into full-screen.
struct PlaceDeckView: View {
    // MARK: - Inputs

    let places: [Place]
    /// Tap callback. `originGlobal` is the card's global frame at the
    /// moment of tap — fed straight into `PlaceSheetView` as the morph
    /// origin so the photo scales out of the card.
    let onTapCard: (Int, CGRect) -> Void
    /// Tap callback for the empty space BETWEEN cards (the cardSpacing
    /// gaps and the horizontal side gutters). The parent uses this to
    /// flip the view-mode toggle back to the bubble cloud — "tap the
    /// background to dismiss" muscle memory from photo apps.
    var onTapBackground: () -> Void = {}

    /// Live scroll / settle knobs from the Spec Toolbox.
    var motionSpecs: PlaceDeckSpecs = PlaceDeckSpecs(
        ComponentSpecState(defaults: StudioItem.verticalCardDeck.specDefaults),
        sheet: StudioItem.verticalCardDeck.specSheet!
    )

    // MARK: - Tunables (expose every "feel" knob up front)

    /// Card aspect ratio (height ÷ width) — matches `SearchResultCard`'s
    /// 1 : 1.44 portrait so a deck card and a result card share exactly
    /// the same height (given the same width). Photo tiles read as the
    /// same object across the two surfaces.
    private let cardAspectRatio: CGFloat    = 1.44
    /// Horizontal margin each card takes from the screen edge — matches
    /// `StudioLayout.horizontalPadding` so widths line up with other stages.
    private var cardHorizontalInset: CGFloat { StudioLayout.horizontalPadding }
    private let cardSpacing: CGFloat        = 18
    private let cardCornerRadius: CGFloat   = 36

    /// Scroll-transition feel — driven by `motionSpecs` when set from
    /// Component Studio; defaults match the original tuned values.
    private var centerScale: CGFloat        { 1.0 }
    private var edgeScale: CGFloat          { CGFloat(motionSpecs.edgeScale) }
    private var centerOpacity: CGFloat      { 1.0 }
    private var edgeOpacity: CGFloat        { CGFloat(motionSpecs.edgeOpacity) }
    private var maxEdgeBlur: CGFloat        { CGFloat(motionSpecs.maxEdgeBlur) }
    private var parallaxAmount: CGFloat     { CGFloat(motionSpecs.parallaxAmount) }

    /// Shadow morphs from deep+soft at centre to tight at the edges.
    private let centerShadowRadius: CGFloat = 28
    private let centerShadowY: CGFloat      = 18
    private let edgeShadowRadius: CGFloat   = 8
    private let edgeShadowY: CGFloat        = 4
    private let shadowColor: Color          = .black.opacity(0.35)

    /// Settle "breathe" on each newly-centred card (post-snap).
    private var settleScale: CGFloat        { CGFloat(motionSpecs.settleScale) }
    private var settleDuration: Double      { motionSpecs.settleDuration }

    // MARK: - State

    /// Tracks which card the scroll has snapped to. Drives the settle
    /// breathe per card and the haptic on landing.
    @State private var centeredID: Place.ID?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            // Card width = viewport width minus the symmetric horizontal
            // inset. Height = width × aspect — keeps deck cards exactly
            // the same height as the result tiles (1 : 1.44 portrait).
            let cardWidth = max(0, geo.size.width - cardHorizontalInset * 2)
            let cardHeight = min(cardWidth * cardAspectRatio, geo.size.height)
            // Top/bottom inset = the leftover space ÷ 2, so the first and
            // last cards can snap to the viewport centre instead of being
            // pinned at the edges.
            let centerInset = max(0, (geo.size.height - cardHeight) / 2)

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: cardSpacing) {
                    ForEach(Array(places.enumerated()), id: \.element.id) { index, place in
                        PlaceDeckCard(
                            place: place,
                            index: index,
                            total: places.count,
                            isCentered: centeredID == place.id,
                            cornerRadius: cardCornerRadius,
                            edgeScale: edgeScale,
                            centerScale: centerScale,
                            edgeOpacity: edgeOpacity,
                            centerOpacity: centerOpacity,
                            maxEdgeBlur: maxEdgeBlur,
                            parallaxAmount: parallaxAmount,
                            centerShadowRadius: centerShadowRadius,
                            centerShadowY: centerShadowY,
                            edgeShadowRadius: edgeShadowRadius,
                            edgeShadowY: edgeShadowY,
                            shadowColor: shadowColor,
                            settleScale: settleScale,
                            settleDuration: settleDuration,
                            reduceMotion: reduceMotion,
                            onTap: { rect in onTapCard(index, rect) }
                        )
                        .frame(height: cardHeight)
                        // 24pt side margins so the card breathes from the
                        // screen edges — matches the search result cards
                        // and reads as a held object, not a poster.
                        .padding(.horizontal, cardHorizontalInset)
                        .id(place.id)
                    }
                }
                .scrollTargetLayout()
                // Tappable layer behind every card — fills the
                // LazyVStack frame which INCLUDES the cardSpacing gaps
                // and the side gutters left by each card's
                // `.padding(.horizontal, 24)`. Cards keep their own tap
                // gestures, so taps on a card are handled by the card;
                // taps in the space BETWEEN cards fall through to this
                // background and trigger `onTapBackground`. Cleaner than
                // a sibling overlay because the ScrollView's scroll
                // gesture still wins on drags.
                .background(
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { onTapBackground() }
                )
            }
            .contentMargins(.vertical, centerInset, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $centeredID, anchor: .center)
            .sensoryFeedback(.selection, trigger: centeredID)
            // Kill iOS 26's automatic scroll-edge fade on both edges —
            // it was painting the hard banded "cut" above the centred
            // card by blurring the peek of the previous one. Without it
            // the neighbouring cards peek cleanly straight to the edge.
            .modifier(NoScrollEdgeEffect())
            // Smooth fade band at the top + bottom of the scroll viewport.
            // 80pt was tuned by eye — small enough that the next card
            // still peeks meaningfully through the partial fade, but
            // big enough that the gradient stays imperceptible (no
            // visible band edge). Combined with the more aggressive
            // `edgeOpacity = 0.3` ramp in `scrollTransition`, the card
            // is already mostly faded by the time it enters this band,
            // so the rounded corner can never appear to "get cut".
            .mask {
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [.clear, .black],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 80)
                    Color.black
                    LinearGradient(
                        colors: [.black, .clear],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 80)
                }
            }
            .onAppear {
                // Seed the centred id to the first card so the breathe +
                // VoiceOver "card 1 of N" announce on initial appearance.
                if centeredID == nil { centeredID = places.first?.id }
            }
        }
    }
}

// MARK: - Scroll edge

/// Hides iOS 26's default scroll edge effect at the top and bottom of
/// the deck. The system normally fades the content as it approaches a
/// scroll edge, which on a deck creates a visible banded "cut" over the
/// peeking neighbour cards. No-op on older OSes.
private struct NoScrollEdgeEffect: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.scrollEdgeEffectHidden(true, for: [.top, .bottom])
        } else {
            content
        }
    }
}

// MARK: - Card

/// One card in the deck. Self-contains the scroll transition (scale /
/// opacity / blur / tilt / shadow), the inner parallax on the photo, the
/// settle breathe when it becomes centred, the tap-to-open callback, and
/// the VoiceOver label.
private struct PlaceDeckCard: View {
    let place: Place
    let index: Int
    let total: Int
    let isCentered: Bool
    let cornerRadius: CGFloat
    let edgeScale: CGFloat
    let centerScale: CGFloat
    let edgeOpacity: CGFloat
    let centerOpacity: CGFloat
    let maxEdgeBlur: CGFloat
    let parallaxAmount: CGFloat
    let centerShadowRadius: CGFloat
    let centerShadowY: CGFloat
    let edgeShadowRadius: CGFloat
    let edgeShadowY: CGFloat
    let shadowColor: Color
    let settleScale: CGFloat
    let settleDuration: Double
    let reduceMotion: Bool
    let onTap: (CGRect) -> Void

    /// Drives the post-snap "inhale" on the centred card. Toggled by
    /// `onChange(of: isCentered)` so it fires once per landing.
    @State private var breathe: CGFloat = 1.0
    /// Last-known global frame; captured every layout pass and fed to
    /// `onTap` so the morph origin matches the card's on-screen rect.
    @State private var lastGlobalFrame: CGRect = .zero

    var body: some View {
        ZStack {
            cardBody
        }
        .scaleEffect(breathe)
        // Shadow lives OUTSIDE `scrollTransition` because that modifier's
        // closure returns a `VisualEffect` and `.shadow` is only available
        // on `View`. We drive it from the binary `isCentered` instead of
        // the continuous phase — visually close enough because the snap
        // animation interpolates the change.
        .shadow(
            color: shadowColor,
            radius: isCentered ? centerShadowRadius : edgeShadowRadius,
            x: 0,
            y: isCentered ? centerShadowY : edgeShadowY
        )
        .animation(.easeOut(duration: 0.3), value: isCentered)
        .scrollTransition(.interactive, axis: .vertical) { content, phase in
            // Single return path so the closure type-checks fast. `t`
            // is 0 at the centred card, 1 at the viewport edges.
            // rotation3D was removed: combined with the ScrollView clip
            // it was making the top corner of the card visually
            // "expand" as the perspective stretched the upper edge.
            // The card still feels like a deck via scale + opacity +
            // blur — just without the tilt artefact.
            let t = abs(phase.value)
            let scale: CGFloat = reduceMotion
                ? 0.97 + (1 - t) * 0.03
                : centerScale - t * (centerScale - edgeScale)
            let opacity: CGFloat = centerOpacity - t * (centerOpacity - edgeOpacity)
            let blur: CGFloat = reduceMotion ? 0 : t * maxEdgeBlur
            return content
                .scaleEffect(scale)
                .opacity(opacity)
                .blur(radius: blur)
        }
        .onChange(of: isCentered) { _, nowCentered in
            guard nowCentered, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: settleDuration)) {
                breathe = settleScale
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + settleDuration) {
                withAnimation(.easeInOut(duration: settleDuration)) {
                    breathe = 1.0
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(place.title), \(place.subtitle), card \(index + 1) of \(total)")
        .accessibilityAddTraits(.isButton)
    }

    /// Card visual — matches the cloud bubble's minimal style: just the
    /// photo with a rounded clip + hairline white stroke, no scrim or
    /// title overlay. The photo carries its own `scrollTransition` so
    /// the Ken-Burns parallax stays inside the card's frame. A
    /// `GeometryReader` background captures the card's global rect for
    /// the tap-to-detail morph origin.
    private var cardBody: some View {
        RemoteImage(url: place.imageURL)
            .scrollTransition(.interactive, axis: .vertical) { content, phase in
                content.offset(y: reduceMotion ? 0 : phase.value * parallaxAmount)
            }
            .clipped()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onChange(of: proxy.frame(in: .global), initial: true) { _, rect in
                            lastGlobalFrame = rect
                        }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            // 2% scale-down on press — mirrors the SearchResultCard
            // `PressableCardStyle` so the deck card has the same
            // tactile press as the search result tiles.
            .modifier(PressableDeckCardModifier { onTap(lastGlobalFrame) })
    }
}

// MARK: - Press feedback

/// 2% scale-down on press; quick spring back on release. Built as a
/// `ViewModifier` (not a `ButtonStyle`) because the deck card already
/// owns its tap gesture via the `onTap` closure — wrapping it in a
/// `Button` would steal that gesture from the surrounding ScrollView
/// and break vertical scroll-to-pan inside the card region.
private struct PressableDeckCardModifier: ViewModifier {
    let onTap: () -> Void
    @State private var isPressed: Bool = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(
                isPressed
                    ? .easeOut(duration: 0.12)
                    : .spring(response: 0.32, dampingFraction: 0.82),
                value: isPressed
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed { isPressed = true }
                    }
                    .onEnded { value in
                        isPressed = false
                        // Only fire tap when the touch barely moved —
                        // larger swipes belong to the ScrollView.
                        let dx = abs(value.translation.width)
                        let dy = abs(value.translation.height)
                        if dx < 10 && dy < 10 { onTap() }
                    }
            )
    }
}
