import SwiftUI

/// Search results — the zoom-transition destination from the search pill.
///
/// Layered structure (back to front):
///   0. `restingLayer` — what the screen settles to (white / glass).
///   1. `introSurface` — the AI gradient + edge glow that fills from the
///      pill via the system `.zoom`, holds, breathes, then dissolves.
///   2. content — a `ScrollView` with the AI summary (per-word blur→focus)
///      and the result cards (staggered cascade), under a pinned top bar
///      with a native scroll edge effect.
struct SearchModalView: View {
    // MARK: - Tunables (tweak here, no hunting through the body)

    /// What sits BEHIND the intro AI gradient. The intro fades out after
    /// the hold and reveals this. Two simple options — swap the constant
    /// below to compare on device.
    ///   `.white` — solid Color.white. Maximum contrast, calm reading.
    ///   `.glass` — native Liquid Glass surface. Stays alive under the
    ///             content.
    enum RestingBackground: Equatable { case white, glass }
    private let restingBackground: RestingBackground = .white

    /// Animation timing — every phase of the intro is here, named.
    /// `holdDuration` is long enough that the gradient → white fade
    /// only kicks in AROUND the time the summary text finishes its
    /// per-word blur→focus (results land at ~1.6s, last word focuses
    /// near ~3s) — so the two transitions feel synced, not sequential.
    private let morphDuration: Double = 0.5      // pill grows into surface
    private let fadeDuration: Double  = 0.7      // surface dissolves out

    /// Top bar — Instagram-style: back chevron, query as the title,
    /// ellipsis menu. Spacing + paddings + title type exposed so the
    /// bar is easy to tune from one place.
    private let headerSpacing: CGFloat            = 12
    private var headerHorizontalPadding: CGFloat { StudioLayout.horizontalPadding }
    private let headerVerticalPadding: CGFloat    = 8
    /// Query field — 14pt semibold (compact input chip).
    private let titleFontSize: CGFloat            = 14
    private let titleFontWeight: Font.Weight      = .semibold

    /// Layout — vertical breathing room around the summary paragraph.
    /// Top gap is tight (summary right under the bar); bottom gap is
    /// noticeably larger so the cards have room to breathe and the
    /// cascade reveal lands in a clear empty space.
    private let summaryTopPadding: CGFloat = 24
    private let cardsTopPadding: CGFloat   = 20

    /// Cards reveal — they wait for the summary blur to fully resolve,
    /// then ease in one-by-one with `cardStagger` between them.
    /// Tiny extra buffer after the last word of the summary focuses,
    /// before the first card starts revealing.
    private let cardRevealBuffer: Double    = 0.08

    /// Typography — summary is the generated sentence. 18pt keeps it a
    /// calm subhead so the cards stay the hero.
    private let summaryFontSize: CGFloat  = 16

    /// Inline keyword icon size — sits just before each keyword
    /// (Instagram's blue magnifying glass before the link). Tinted with
    /// the keyword's gradient.
    private let keywordIconSize: CGFloat  = 11

    /// Colored surface palette — same as Aurora.AI.stops the pill uses,
    /// kept as a constant so the modal and the pill stay visually tied.
    /// Used for both the surface gradient AND the keyword text/icons.
    private let gradientColors: [Color] = Aurora.AI.stops

    /// Header "AI text loading" feel — text is rendered when results land
    /// (no placeholder bars anymore), starts blurred + faded and resolves
    /// into focus per-word. `blurRevealDuration` is the duration each word
    /// takes to focus — slower than before so the effect is felt.

    /// Colored aura intensity — TRAVADA at the pill's level (matches
    /// SearchBoxView.aiAura.opacity 0.20 focused). The modal does NOT
    /// paint a more saturated full-screen gradient; it just scales this
    /// same intensity to fit the surface as it grows.
    private let auraOpacity: Double             = 0.22
    private let auraBlur: CGFloat               = 60.0

    /// Edge glow (rotating angular-gradient stroke at the screen rim).
    private let glowLineWidth: CGFloat        = 2.0
    private let glowBlur: CGFloat             = 6.0
    private let glowRotationPeriod: Double    = 6.0   // seconds / full turn

    // MARK: - Inputs

    let query: String
    /// Pushed by `BubbleCloudView` so the nav-bar search field can
    /// submit a new query and rebuild the results page. Optional so
    /// the view stays usable from previews / standalone tests.
    let onSubmitNewQuery: ((String) -> Void)?

    /// Live blur / reveal knobs from the Spec Toolbox.
    var motionSpecs: SearchModalSpecs

    init(
        query: String,
        onSubmitNewQuery: ((String) -> Void)? = nil,
        motionSpecs: SearchModalSpecs = SearchModalSpecs(
            ComponentSpecState(defaults: StudioItem.blurFocusLoading.specDefaults),
            sheet: StudioItem.blurFocusLoading.specSheet!
        )
    ) {
        self.query = query
        self.onSubmitNewQuery = onSubmitNewQuery
        self.motionSpecs = motionSpecs
        _editableQuery = State(initialValue: query)
    }

    // MARK: - State

    @State private var results: [Place] = []
    /// Poetic one-sentence summary returned by Claude. Empty until the
    /// API call resolves; the `summaryWords` builder falls back to a
    /// canned template if this stays empty (offline / no API key).
    @State private var apiSummary: String = ""
    /// Non-nil after a failed API call. Surfaced as a tiny inline note
    /// under the summary so the user knows results are local / static.
    @State private var apiError: String?
    /// Bound to the nav-bar search TextField. Seeded with `query` so
    /// the field opens pre-filled with the current term.
    @State private var editableQuery: String = ""
    @FocusState private var searchFocused: Bool
    /// True the moment the scroll view's content offset goes past the
    /// top edge. Drives the nav-bar backdrop's Liquid Glass material:
    /// invisible at rest, fades in on scroll — same behaviour as iOS 26
    /// native nav bars in Music, Mail and Photos.
    @State private var scrolledPastTop: Bool = false
    /// Drives the staggered content reveal — the surface morph runs first,
    /// then the summary cross-fades in on top.
    @State private var contentVisible = false
    /// Flips to true once the summary's per-word blur has resolved.
    /// Cards observe this and cascade in (each delayed by index).
    @State private var cardsVisible = false

    // Intro lifecycle — single source of truth so the sequence is
    // interruptible and easy to reason about.
    @State private var introVisible: Bool = true
    @State private var introScale: CGFloat = 1.0

    // Edge-glow rotation: continuous free spin until `fading` flips on,
    // after which the angle eases toward `angleAtFadeStart + maxIncrement`
    // with a cubic easeOut — rotation never stops abruptly.
    @State private var fading: Bool = false
    @State private var fadeStartDate: Date = Date()
    @State private var angleAtFadeStart: Double = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Layer 0 — Resting background. What the screen settles to
            // after the intro dissolves. Behind everything; only visible
            // once the intro layer has faded out.
            restingLayer
                .ignoresSafeArea()

            // Layer 1 — Intro surface. Same visual identity as the pill
            // (Color.white base + low-opacity colored aura + edge glow).
            // The system's `.zoom` navigation transition handles the
            // morph FROM the pill's frame + corner radius TO this view's
            // natural full-screen frame — position, size and corner
            // radius are all interpolated by Apple's nav spring. No
            // matched-geometry or morphProgress required here.
            // The aura is locked at `auraOpacity` (matches the pill's
            // aiAura) so there's no intensity jump: the same color
            // intensity that fills the pill fills the screen.
            // After the hold, the whole layer dissolves out (opacity +
            // sutil scale expand) revealing layer 0 below.
            introSurface
                .scaleEffect(introScale)
                .opacity(introVisible ? 1.0 : 0.0)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // Layer 2 — Content. Instagram-style: a single top bar
            // (back + query + ellipsis) pinned to the top via
            // `safeAreaInset`, with the summary + cards scrolling
            // below.
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    supportingArea
                        // Leading inset = the app's 24pt margin + the
                        // 4pt gap between the back button's 44pt tap
                        // target and its 36pt visible Liquid Glass
                        // circle. The summary's left edge now lands
                        // exactly on the circle's leading border, not
                        // the chevron glyph centre.
                        .padding(.leading, StudioLayout.horizontalPadding + 4)
                        .padding(.trailing, StudioLayout.horizontalPadding)
                        .padding(.top, summaryTopPadding)

                    VStack(spacing: 12) {
                        ForEach(Array(results.enumerated()), id: \.element.id) { index, place in
                            Button(action: { }) {
                                SearchResultCard(place: place)
                            }
                            .buttonStyle(PressableCardStyle())
                            // Cards stay invisible + shifted down until
                            // `cardsVisible` flips (after the summary
                            // blur ends), then each one eases in with
                            // its own per-index delay → cascade.
                            .opacity(cardsVisible ? 1 : 0)
                            .offset(y: cardsVisible ? 0 : 28)
                            .animation(
                                .easeOut(duration: motionSpecs.cardRevealDuration)
                                    .delay(Double(index) * motionSpecs.cardStagger),
                                value: cardsVisible
                            )
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(place.title), \(place.subtitle)")
                            .accessibilityAddTraits(.isButton)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    // 24pt inset — app-wide horizontal margin so the
                    // result cards line up with the top bar buttons,
                    // the deck cards, and the summary text above.
                    .padding(.horizontal, StudioLayout.horizontalPadding)
                    .padding(.top, cardsTopPadding)
                }
                .padding(.bottom, 72)
            }
            .scrollIndicators(.hidden)
            .scrollContentBackground(.hidden)
            .modifier(SoftTopScrollEdge())
            .modifier(ScrolledPastTopTracker(scrolledPastTop: $scrolledPastTop))
            .opacity(contentVisible ? 1 : 0)
            .safeAreaInset(edge: .top, spacing: 0) {
                // 60pt breath above the bar so the loading reads more
                // grounded — the summary sits noticeably lower in the
                // viewport, leaving the bar floating below the gradient
                // surface peak.
                topBar
                    .padding(.top, 120)
            }
        }
        .tint(Aurora.accent)
        .task { await runIntroLifecycle() }
        .task { await revealContent() }
        .task { await run() }
    }

    // MARK: - Top bar (Instagram-style)

    /// Single top bar: back chevron, query as the heavy title, ellipsis
    /// menu. Always visible (pinned via `safeAreaInset(.top)`). On iOS 26
    /// the native scroll edge effect keeps it legible, so the backdrop is
    /// clear; on older OSes it carries a frosted `.ultraThinMaterial`.
    private var topBar: some View {
        HStack(spacing: headerSpacing) {
            backButton
            navSearchField
        }
        .padding(.horizontal, headerHorizontalPadding)
        .padding(.vertical, headerVerticalPadding)
        .frame(maxWidth: .infinity)
        .background(topBarBackdrop)
    }

    /// Inline Liquid Glass search field — replaces the static query
    /// title. Pre-filled with the current query, editable, submits a
    /// new `SearchRequest` via `onSubmitNewQuery` so the results page
    /// refreshes for the new term. `sparkles` icon tinted with the AI
    /// gradient ties this field visually to the floating AI search pill
    /// in `SearchBoxView` — same conversation, two surfaces.
    private var navSearchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Aurora.ink.opacity(0.5))
            TextField("Search", text: $editableQuery)
                .font(AppFont.manrope(titleFontSize, titleFontWeight,
                                      relativeTo: .body))
                .foregroundStyle(Aurora.ink.opacity(0.8))
                .focused($searchFocused)
                .submitLabel(.search)
                .lineLimit(1)
                .onSubmit {
                    let trimmed = editableQuery.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty, trimmed != query else { return }
                    onSubmitNewQuery?(trimmed)
                }
            // Trailing clear-query affordance. Placeholder only — no
            // tap action wired yet. The xmark.circle.fill is iOS's
            // canonical "clear" glyph in search fields.
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Aurora.ink.opacity(0.2))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 12)
        // Pinned to 36pt so the capsule matches the back-button glass
        // circle exactly — bar reads as a coherent row of equal-height
        // controls.
        .frame(height: 36)
        .modifier(NavSearchFieldGlass())
        .layoutPriority(1)
    }

    /// Pure-blur nav-bar backdrop (option B): invisible at rest, then
    /// fades in `.ultraThinMaterial` on scroll — no Liquid Glass surface
    /// layer, just the blur "shader" feel. Trade-off vs the iOS 26
    /// `.glassEffect` route: lighter / more transparent, but doesn't
    /// pick up the Liquid Glass luminance + refraction.
    private var topBarBackdrop: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            // Disabled: 0 in both states keeps the top region fully
            // transparent — content scrolls under the bar with no
            // blur or material backing.
            .opacity(0)
            .animation(.easeInOut(duration: 0.22), value: scrolledPastTop)
            .ignoresSafeArea(edges: .top)
    }

    /// Back chevron — Liquid Glass circle on iOS 26 (the material
    /// reacts to touch/pointer via `.interactive()`), `.ultraThinMaterial`
    /// on older OSes. Pops the destination off the NavigationStack and
    /// lets the system's `.zoom` transition reverse for free. 44×44 tap
    /// target wrapping a 36×36 visible circle.
    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Aurora.ink.opacity(0.4))
                .frame(width: 36, height: 36)
                .modifier(NavGlassCircle())
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }

    // MARK: - Resting background (under the intro layer)

    /// What the screen settles to once the intro layer dissolves.
    /// `.white` is a flat Color.white — calm and high-contrast.
    /// `.glass` is a Liquid Glass surface on iOS 26 (material fallback
    /// below) — we're not animating anything turning white, just removing
    /// the gradient overlay and revealing the surface beneath.
    @ViewBuilder
    private var restingLayer: some View {
        switch restingBackground {
        case .white:
            Color.white
        case .glass:
            if #available(iOS 26.0, *) {
                Color.clear.glassEffect(.clear, in: Rectangle())
            } else {
                Rectangle().fill(.ultraThinMaterial)
            }
        }
    }

    // MARK: - Intro surface (white identity + colored aura + edge glow)

    /// The surface that grows from the pill — built to match the pill's
    /// look at any size, not to introduce new intensity.
    ///   • `Color.white`  → carries the pill's Liquid-Glass-on-white feel.
    ///   • `coloredAura`  → SAME AngularGradient + opacity as the pill's
    ///                      aiAura. No saturation boost on full-screen.
    ///   • `edgeGlow`     → rotating angular stroke (kept from before).
    /// No manual clip shape — the system's `.zoom` interpolates the
    /// corner radius from the source (26pt, declared in `ZoomSourceMod`)
    /// to this view's natural full-screen 0pt automatically.
    private var introSurface: some View {
        ZStack {
            Color.white
            coloredAura
            edgeGlow
        }
    }

    /// Colored aura — identical to the pill's `aiAura` definition:
    /// angular gradient over the AI palette, heavily blurred, capped at
    /// `auraOpacity` (the pill's focused level). Travada na intensidade
    /// da pill — não anima de baixo→alto durante o morph; ela apenas
    /// preenche o frame conforme a surface cresce.
    private var coloredAura: some View {
        TimelineView(.animation) { tl in
            let raw = tl.date.timeIntervalSinceReferenceDate
            let period: Double = 4.0
            let angle = reduceMotion
                ? 0.0
                : (raw.truncatingRemainder(dividingBy: period) / period) * 360
            Rectangle()
                .fill(
                    AngularGradient(
                        gradient: Gradient(
                            colors: gradientColors + [gradientColors[0]]
                        ),
                        center: .center,
                        angle: .degrees(angle)
                    )
                )
                .blur(radius: auraBlur)
                .opacity(auraOpacity)
        }
        .allowsHitTesting(false)
    }

    /// Animated angular-gradient stroke around the screen rim. Continuous
    /// free spin until `fading` flips on; from then on the angle eases
    /// (cubic easeOut) over `fadeDuration`, so the rotation decelerates
    /// instead of stopping abruptly. The decel arc is approximated as half
    /// of what a full-speed pass would have done in that window — the
    /// integral of an easeOut speed curve, near enough for the eye.
    private var edgeGlow: some View {
        TimelineView(.animation) { tl in
            let baseRate = 360.0 / glowRotationPeriod          // °/s
            let angle: Double = {
                if reduceMotion { return 0 }
                if !fading {
                    let raw = tl.date.timeIntervalSinceReferenceDate
                    return (raw * baseRate).truncatingRemainder(dividingBy: 360)
                }
                let elapsed = max(0, tl.date.timeIntervalSince(fadeStartDate))
                let p = min(elapsed / fadeDuration, 1.0)
                let eased = 1 - pow(1 - p, 3)
                let maxIncrement = baseRate * fadeDuration * 0.5
                return angleAtFadeStart + maxIncrement * eased
            }()
            Rectangle()
                .strokeBorder(
                    AngularGradient(
                        gradient: Gradient(
                            colors: gradientColors + [gradientColors[0]]
                        ),
                        center: .center,
                        angle: .degrees(angle)
                    ),
                    lineWidth: glowLineWidth
                )
                .blur(radius: glowBlur)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Lifecycle

    /// One linear sequence — interruptible (held in @State), respects
    /// Reduce Motion, no nested Tasks. Three phases:
    ///   1. MORPH (~morphDuration)  — matched geometry handles it externally.
    ///   2. HOLD  (~holdDuration)   — slow breathe 1.0 → 1.03 → 1.0 so the
    ///      screen never reads as frozen.
    ///   3. FADE  (~fadeDuration)   — gradient + glow dissolve together
    ///      (opacity → 0) with a sutil scale expand to 1.05; glow rotation
    ///      decelerates along the same easeOut curve.
    private func runIntroLifecycle() async {
        // Phase 1 — Morph (matched geometry already driving it).
        try? await Task.sleep(nanoseconds: UInt64(morphDuration * 1_000_000_000))

        // Phase 2 — Hold + breathe.
        if reduceMotion {
            try? await Task.sleep(nanoseconds: UInt64(motionSpecs.holdDuration * 1_000_000_000))
        } else {
            let half = motionSpecs.holdDuration / 2
            withAnimation(.easeInOut(duration: half)) { introScale = 1.03 }
            try? await Task.sleep(nanoseconds: UInt64(half * 1_000_000_000))
            withAnimation(.easeInOut(duration: half)) { introScale = 1.0 }
            try? await Task.sleep(nanoseconds: UInt64(half * 1_000_000_000))
        }

        // Phase 3 — Dissolve. Reduce Motion gets a short flat crossfade;
        // full motion gets the sutil scale + glow decel.
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.4)) {
                introVisible = false
            }
        } else {
            // Anchor the rotation where it currently is so the decel
            // starts continuously — no visible jump.
            let baseRate = 360.0 / glowRotationPeriod
            let now = Date()
            angleAtFadeStart = (now.timeIntervalSinceReferenceDate * baseRate)
                .truncatingRemainder(dividingBy: 360)
            fadeStartDate = now
            fading = true

            withAnimation(.easeInOut(duration: fadeDuration)) {
                introVisible = false
                introScale = 1.05
            }
        }
    }

    /// Holds the inner content back until the surface morph has settled
    /// (~morphDuration) plus a short ~0.15s pause, so the surface relaxes
    /// into its final shape BEFORE the text + cards + close fade in.
    /// Two-beat entrance: surface assenta → conteúdo materializa.
    private func revealContent() async {
        let delay = morphDuration + 0.15
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        withAnimation(.easeOut(duration: 0.34)) {
            contentVisible = true
        }
    }

    // MARK: - Card press feedback (Button + ButtonStyle, scroll-safe)

    /// `Button` + `ButtonStyle` is the only approach that guarantees
    /// the ScrollView's pan gesture isn't blocked — UIKit specifically
    /// disambiguates buttons inside scroll views so the page always
    /// scrolls under the finger. `configuration.isPressed` is true on
    /// touch-down (after a tiny UIKit delay to filter scroll attempts)
    /// and goes false on either tap completion OR scroll start. Quick
    /// Applies the native iOS 26 soft scroll edge effect on the top edge;
    /// a no-op on earlier OSes (the top bar's frosted material covers it).
    fileprivate struct SoftTopScrollEdge: ViewModifier {
        @ViewBuilder
        func body(content: Content) -> some View {
            if #available(iOS 26.0, *) {
                content.scrollEdgeEffectStyle(.soft, for: .top)
            } else {
                content
            }
        }
    }

    /// Quick scale-down + slightly slower scale-up so the press registers
    /// even when the scroll wins the gesture.
    fileprivate struct PressableCardStyle: ButtonStyle {
        // Default rest scale matches what the card used to show under
        // press (0.97), so the at-rest tile is now smaller by default.
        // Press goes a bit further (0.92) — still gives a visible
        // tactile feedback on top of the shrunken default.
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.92 : 0.97)
                .animation(
                    configuration.isPressed
                        ? .easeOut(duration: 0.14)
                        : .spring(response: 0.34, dampingFraction: 0.86),
                    value: configuration.isPressed
                )
        }
    }



    // MARK: - Summary content (blur-to-focus per word, inline keywords)

    /// The summary is rendered by `supportingArea`, sitting
    /// `summaryTopPadding` below the top bar. Each word starts blurred
    /// (`blurAmount`) + faded (opacity 0.3) and animates to nítido on a
    /// slower easeOut (`blurRevealDuration`), with a per-word stagger.
    /// Keywords (place names) are rendered as `WordSeg.keyword` —
    /// composite Image+Text laid out as a single FlowLayout item, so
    /// the inline icon never wraps away from the keyword word.

    // MARK: - Supporting area (blur-focused summary, no loading bars)

    /// Loading bars are gone — only the real text appears, with the
    /// blur→focus per-word reveal. While results are loading this is
    /// simply empty space; once `results` is filled the BlurFocusFlow
    /// mounts and its `.onAppear` kicks the animation.
    @ViewBuilder
    private var supportingArea: some View {
        if !results.isEmpty {
            BlurFocusFlow(
                words: summaryWords,
                font: AppFont.manrope(summaryFontSize, .light, relativeTo: .body),
                blurAmount: CGFloat(motionSpecs.blurAmount),
                wordStagger: motionSpecs.wordStagger,
                blurRevealDuration: motionSpecs.blurRevealDuration,
                startDelay: 0,                  // top bar already up
                reduceMotion: reduceMotion,
                keywordIconSize: keywordIconSize
            )
            .lineSpacing(6)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(summaryAccessibilityLabel)
        }
    }

    /// Builds the per-word segments for the summary. Place names are
    /// `.keyword` segments — composite Image+Text rendered as a single
    /// FlowLayout item so the inline magnifier icon never wraps away
    /// from the keyword. Keyword icons and text both pull from
    /// `Aurora.AI.still` (the AI gradient); connective text is
    /// `Aurora.ink` (the project's deep ink color) for high contrast
    /// on both the colored gradient phase and the white resting bg.
    /// The query word at the start keeps its plain `.text` form in
    /// AI gradient — the magnifier icons are reserved for the place
    /// keywords (Instagram's "lupa antes do link" pattern).
    private var summaryWords: [WordSeg] {
        let names = Array(results.prefix(2).map(\.title))
        let aiStyle = AnyShapeStyle(Aurora.AI.still)
        let inkStyle = AnyShapeStyle(Aurora.ink)
        var words: [WordSeg] = []
        var i = 0

        func pushText(_ text: String, _ style: AnyShapeStyle) {
            let segs = Self.splitText(text, style: style, startIndex: i)
            words.append(contentsOf: segs)
            i += segs.count
        }

        func pushKeyword(_ name: String) {
            words.append(
                WordSeg(
                    index: i,
                    kind: .keyword(icon: "magnifyingglass", text: name),
                    style: aiStyle
                )
            )
            i += 1
        }

        // When the API returned a real summary, render it directly with
        // each place name lifted out as a keyword segment (magnifier
        // icon + AI gradient) so it visually echoes Instagram's "lupa
        // antes do link" pattern. Falls back to the canned template
        // when offline / no API key.
        if !apiSummary.isEmpty {
            renderSummary(apiSummary, names: names, pushText: pushText, pushKeyword: pushKeyword, inkStyle: inkStyle)
            return words
        }

        if names.count >= 2 {
            pushKeyword(names[0])
            pushText("and", inkStyle)
            pushKeyword(names[1])
            pushText("are calm, scenic places worth the drift.", inkStyle)
        } else if names.count == 1 {
            pushKeyword(names[0])
            pushText("is a calm, scenic place worth the drift.", inkStyle)
        }
        return words
    }

    /// Walks the API summary token by token, replacing each occurrence
    /// of a result's place name with a keyword segment (magnifier icon
    /// + AI-gradient text). Case-insensitive, whole-word match — falls
    /// back to plain text for everything else.
    private func renderSummary(
        _ summary: String,
        names: [String],
        pushText: (String, AnyShapeStyle) -> Void,
        pushKeyword: (String) -> Void,
        inkStyle: AnyShapeStyle
    ) {
        // Sort longest-first so multi-word names ("Lake Bled") match
        // before a substring would.
        let sortedNames = names.sorted { $0.count > $1.count }
        var remainder = summary[summary.startIndex..<summary.endIndex]

        while !remainder.isEmpty {
            // Find the earliest match across all names.
            var earliest: (range: Range<Substring.Index>, original: String)? = nil
            for name in sortedNames {
                if let r = remainder.range(of: name, options: .caseInsensitive),
                   earliest == nil || r.lowerBound < earliest!.range.lowerBound {
                    earliest = (r, name)
                }
            }
            guard let hit = earliest else {
                pushText(String(remainder), inkStyle)
                return
            }
            let prefix = remainder[remainder.startIndex..<hit.range.lowerBound]
            if !prefix.isEmpty {
                pushText(String(prefix), inkStyle)
            }
            pushKeyword(hit.original)
            remainder = remainder[hit.range.upperBound..<remainder.endIndex]
        }
    }

    private var summaryAccessibilityLabel: String {
        if !apiSummary.isEmpty { return apiSummary }
        let names = Array(results.prefix(2).map(\.title))
        if names.count >= 2 {
            return "\(names[0]) and \(names[1]) are calm, scenic places worth the drift."
        }
        if names.count == 1 {
            return "\(names[0]) is a calm, scenic place worth the drift."
        }
        return query
    }

    /// Splits a phrase into text `WordSeg`s by whitespace, assigning
    /// sequential indices for the per-word stagger. Empty splits are
    /// skipped. Icon segments are appended separately by the caller.
    private static func splitText(_ text: String, style: AnyShapeStyle, startIndex: Int) -> [WordSeg] {
        var out: [WordSeg] = []
        var i = startIndex
        for chunk in text.split(whereSeparator: \.isWhitespace) {
            let s = String(chunk)
            guard !s.isEmpty else { continue }
            out.append(WordSeg(index: i, kind: .text(s), style: style))
            i += 1
        }
        return out
    }

    // MARK: - Choreography

    private func run() async {
        // Fire the Claude call immediately. While we wait, the intro
        // surface + edge glow is already animating — there's no need
        // to pad with an extra sleep. If the API succeeds, the real
        // dynamic results land; if it fails (no key, offline, etc.)
        // we fall back to the local deterministic ranking so the page
        // never sits empty.
        do {
            let resp = try await PlaceSearchService.search(query: query)
            results = resp.places
            apiSummary = resp.summary
        } catch {
            // Soft fallback — log the reason so it's discoverable but
            // keep the UI alive with the original local results.
            apiError = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
            results = Self.makeResults(for: query)
            // Minimum perceived "thinking" time so the fallback path
            // doesn't snap-render before the intro surface finishes.
            try? await Task.sleep(nanoseconds: 700_000_000)
        }

        AccessibilityNotification.Announcement(
            "Found \(results.count) places for \(query)"
        ).post()

        // Wait for the summary's per-word blur to fully resolve. Total
        // blur time = base duration + (lastIndex * stagger), then a
        // tiny buffer so the cards don't step on the last word of the
        // sentence. After that, flip `cardsVisible` so the cards
        // cascade in (each card's own `.animation(...delay(idx*stagger))`
        // handles the per-card timing).
        let wordCount = summaryWords.count
        let blurEndTime = motionSpecs.blurRevealDuration
            + Double(max(0, wordCount - 1)) * motionSpecs.wordStagger
            + cardRevealBuffer
        try? await Task.sleep(nanoseconds: UInt64(blurEndTime * 1_000_000_000))
        cardsVisible = true
    }

    // MARK: - Blur-to-focus word infra

    /// One "word" in the sentence — text, a standalone SF Symbol, or
    /// a composite keyword (icon + text laid out as a single unit so
    /// they never wrap apart). `index` drives the per-word stagger.
    fileprivate struct WordSeg: Identifiable {
        enum Kind {
            case text(String)
            case icon(String)
            case keyword(icon: String, text: String)
        }
        let index: Int
        let kind: Kind
        let style: AnyShapeStyle
        var id: Int { index }
    }

    /// Lays out a list of `WordSeg`s in a wrapping flow and animates each
    /// word from (blur, opacity 0.3) → (0, 1.0) with a slow easeOut,
    /// delayed by `index * wordStagger + startDelay`. The duration is
    /// long enough (~1s) that the focus is felt, not blinked. Reduce
    /// Motion replaces the stagger + blur with a single short fade-in.
    fileprivate struct BlurFocusFlow: View {
        let words: [WordSeg]
        let font: Font
        let blurAmount: CGFloat
        let wordStagger: Double
        let blurRevealDuration: Double
        let startDelay: Double
        let reduceMotion: Bool
        let keywordIconSize: CGFloat

        @State private var focused = false

        var body: some View {
            FlowLayout(spacing: 4, lineSpacing: 4) {
                ForEach(words) { word in
                    wordView(word)
                        .blur(radius: focused || reduceMotion ? 0 : blurAmount)
                        .opacity(focused ? 1.0 : (reduceMotion ? 0.0 : 0.3))
                        .animation(
                            animation(for: word.index),
                            value: focused
                        )
                }
            }
            .onAppear {
                // Single trigger — `animation(...)` reads the per-word
                // delay so words resolve in order from a single state
                // flip, no per-word Tasks needed.
                focused = true
            }
        }

        @ViewBuilder
        private func wordView(_ word: WordSeg) -> some View {
            switch word.kind {
            case .text(let s):
                Text(s)
                    .font(font)
                    .foregroundStyle(word.style)
            case .icon(let name):
                Image(systemName: name)
                    .font(font)
                    .foregroundStyle(word.style)
            case .keyword(let icon, let text):
                // Composite item: the magnifier glyph + the keyword
                // word in a tight HStack. FlowLayout sees this as ONE
                // subview, so the icon never wraps onto a different
                // line than the word it precedes.
                HStack(spacing: 3) {
                    Image(systemName: icon)
                        .font(.system(size: keywordIconSize, weight: .semibold))
                        .foregroundStyle(word.style)
                    Text(text)
                        .font(font)
                        .foregroundStyle(word.style)
                }
            }
        }

        private func animation(for index: Int) -> Animation {
            if reduceMotion {
                return .easeOut(duration: 0.25)
            }
            return .easeOut(duration: blurRevealDuration)
                .delay(startDelay + Double(index) * wordStagger)
        }
    }

    /// Wrapping flow layout — places subviews left-to-right and wraps to
    /// the next line when the proposed width is exhausted. Used by
    /// `BlurFocusFlow` so each word can be a separate animatable Text.
    fileprivate struct FlowLayout: Layout {
        var spacing: CGFloat = 4
        var lineSpacing: CGFloat = 4

        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
            let maxW = proposal.width ?? .infinity
            var rows: [CGFloat] = []   // line widths
            var rowH: [CGFloat] = []   // line heights
            var x: CGFloat = 0
            var h: CGFloat = 0

            for sv in subviews {
                let s = sv.sizeThatFits(.unspecified)
                if x + s.width > maxW && x > 0 {
                    rows.append(x - spacing)
                    rowH.append(h)
                    x = 0
                    h = 0
                }
                x += s.width + spacing
                h = max(h, s.height)
            }
            if x > 0 {
                rows.append(x - spacing)
                rowH.append(h)
            }
            let totalW = rows.max() ?? 0
            let totalH = rowH.reduce(0, +) + CGFloat(max(0, rowH.count - 1)) * lineSpacing
            return CGSize(width: totalW, height: totalH)
        }

        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
            var x = bounds.minX
            var y = bounds.minY
            var lineH: CGFloat = 0
            for sv in subviews {
                let s = sv.sizeThatFits(.unspecified)
                if x + s.width > bounds.maxX && x > bounds.minX {
                    x = bounds.minX
                    y += lineH + lineSpacing
                    lineH = 0
                }
                sv.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
                x += s.width + spacing
                lineH = max(lineH, s.height)
            }
        }
    }

    // MARK: - Simulated AI content

    /// Rank places by how well their name matches the query.
    private static func makeResults(for query: String) -> [Place] {
        let tokens = query.lowercased()
            .split { !$0.isLetter }
            .map(String.init)
            .filter { $0.count >= 3 }

        var hash = 5381
        for scalar in query.unicodeScalars { hash = (hash &* 33) &+ Int(scalar.value) }

        var scored: [(place: Place, score: Int)] = []
        var seen = Set<String>()
        for i in 0..<240 {
            let col = abs(hash &+ i &* 37) % 4000
            let row = abs((hash &* 7) &+ i &* 101) % 4000
            let place = PlaceData.place(col: col, row: row)
            if !seen.insert(place.id).inserted { continue }
            let hay = place.title.lowercased()
            let score = tokens.reduce(0) { $0 + (hay.contains($1) ? 1 : 0) }
            scored.append((place, score))
        }

        return scored
            .sorted { $0.score > $1.score }
            .prefix(6)
            .map(\.place)
    }
}

// MARK: - Liquid Glass nav button backdrop (iOS 26) + material fallback

/// Circular Liquid Glass backdrop for the nav bar buttons.
/// iOS 26 uses the native `.glassEffect(.regular.interactive(), in: Circle())`
/// so the surface refracts the content behind it and reacts to touch/pointer
/// the way Apple's own toolbar buttons do. On iOS < 26 it falls back to
/// `.ultraThinMaterial` — same shape, same height, just a non-reactive fill.
/// Bridges iOS 18+'s `onScrollGeometryChange` to a Binding, with a
/// no-op fallback on older OSes (where the backdrop just stays at its
/// rest opacity — acceptable since iOS < 18 doesn't have Liquid Glass
/// anyway).
private struct ScrolledPastTopTracker: ViewModifier {
    @Binding var scrolledPastTop: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: Bool.self) { geo in
                geo.contentOffset.y > 2
            } action: { _, isPast in
                scrolledPastTop = isPast
            }
        } else {
            content
        }
    }
}

private struct NavGlassCircle: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.clear.interactive(), in: Circle())
        } else {
            content.background(Circle().fill(.ultraThinMaterial))
        }
    }
}

/// Capsule Liquid Glass backdrop for the inline nav-bar search field.
/// `.interactive()` gives it the same touch/pointer response the
/// system nav-bar search uses; `.ultraThinMaterial` fallback keeps it
/// distinct on iOS < 26.
private struct NavSearchFieldGlass: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.clear.interactive(), in: Capsule())
        } else {
            content.background(Capsule().fill(.ultraThinMaterial))
        }
    }
}
