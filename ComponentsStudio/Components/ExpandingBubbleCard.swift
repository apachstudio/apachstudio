import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Expanding bubble card (tap → 6 satellites burst out)
//
// Wraps a `BubbleView` with a tap-to-toggle interaction. Tap the main
// once: 6 satellites — identical visual specs to the main (same
// `BubbleView`, same size, same 22pt corner radius) — burst outward
// in a slightly chaotic hex orbit. They're free to bleed off the
// device edges; that's intentional. Tap again: they retract on the
// EXACT SAME spring, played in reverse.
//
// Breathing model (the heart of the motion):
//   · Idle — every card (main + 6 satellites) is wrapped in an
//     `IdleBreathingCard`, a `TimelineView`-driven sin oscillator
//     that scales the card ±2 % around 1.0 on a 5 s cycle. Each
//     card carries its own phase offset, so the orbit doesn't
//     breathe in unison — it feels alive, not mechanical.
//   · Tap — the main card adds a pronounced "pop" on top of its idle
//     breath: a slow inhale (1.0 → 0.88) followed immediately by
//     an exhale back to 1.0. The pop fires instantly on tap (no
//     dispatch / no delay) and reads as a deliberate breath.
//
// Same specs in both directions:
//   · `burstAnimation` — single spring drives the satellites
//     opening AND closing. Slow, smooth, no bounce.
//   · `inhaleAnimation` / `exhaleAnimation` — same on every tap,
//     so opening and closing feel like the same breath cycle.
//
// Responsiveness:
//   · The inhale is 12 % deep so the very first frame after tap is
//     visibly different. No "where did my tap go" feel.
//   · We use `withAnimation(_:_:completion:)` to chain inhale →
//     exhale instead of `DispatchQueue.main.asyncAfter`, so the
//     return half kicks off the instant the inhale settles.

struct ExpandingBubbleCard: View {
    let place: Place
    /// Optional custom places for the 6 satellite slots. If non-nil and
    /// containing at least 6 entries, these override the synthesised
    /// stand-ins — used by the pizza-ingredient stage to show real
    /// ingredient photos around the pizza main.
    let satellites: [Place]?
    let size: CGFloat
    let rotation: Double

    init(
        place: Place,
        satellites: [Place]? = nil,
        size: CGFloat,
        rotation: Double = 0
    ) {
        self.place = place
        self.satellites = satellites
        self.size = size
        self.rotation = rotation
    }

    @State private var expanded: Bool = false
    /// Tap-fired pop multiplier on top of the main's idle breath.
    /// 1.0 at rest, dips to `popDepth` on every tap, then settles.
    @State private var pop: CGFloat = 1.0
    /// Currently highlighted preset chip in the tab bar. Tapping a
    /// chip resets `config` to that preset's defaults, so the chip
    /// row is also a "reset to defaults" affordance.
    @State private var preset: MotionPreset = .cascade
    /// The actual animation parameters in use. Initialised from the
    /// default preset and freely tweakable from the expanded sliders.
    @State private var config: MotionConfig = MotionPreset.cascade.defaultConfig()
    /// Layout / idle-state parameters. Driven by the Position panel
    /// inside the control bar.
    @State private var position: PositionConfig = .defaults
    /// Whether the toolbox is showing its specs panel under the chip
    /// row. Lifted here so the floating tools FAB (outside the box)
    /// can flip it directly when the user wants to jump straight into
    /// the code view.
    @State private var controlBarExpanded: Bool = false
    /// Whether the toolbox is in its code-view sub-mode. The tools
    /// FAB outside the box opens code view; the dismiss FAB inside
    /// the box closes it.
    @State private var showCode: Bool = false
    /// Snapshot of `controlBarExpanded` right before the user opened
    /// the code view. Dismissing the code view (via the X inside the
    /// toolbox) restores the toolbox to THIS state — if it was
    /// collapsed when the user tapped the tools FAB, it goes back to
    /// collapsed; if it was expanded, it stays expanded.
    @State private var expandedStateBeforeCode: Bool = false
    /// Persistent offset applied to the CARDS canvas — accumulates
    /// every drag so the user can park the bubble composition
    /// anywhere on the stage. Does NOT move the control bar.
    @State private var canvasSavedOffset: CGSize = .zero
    @GestureState private var canvasDragTranslation: CGSize = .zero

    /// Spring used for the tools FAB → code-view morph. Matches the
    /// toolbox's internal morph anim so both transitions land in sync.
    private let toolboxMorphAnim: Animation =
        .spring(response: 0.55, dampingFraction: 0.78)

    /// Inhale of the main's tap-pop. Slower than before so the breath
    /// reads as elegant, but the pop value is pronounced (0.88) so the
    /// first frame post-tap is visibly different — tap feels instant.
    private let inhaleAnimation: Animation =
        .spring(response: 0.55, dampingFraction: 0.78)

    /// Exhale — a touch slower than the inhale so the return reads as
    /// a gentle release, not a snap.
    private let exhaleAnimation: Animation =
        .spring(response: 0.70, dampingFraction: 0.82)

    /// How far the main squishes at the peak of the inhale. Generous
    /// enough that the response is unmistakable.
    private let popDepth: CGFloat = 0.88

    /// Satellites match the main's visual specs (same `BubbleView`,
    /// same size, same corner radius). Orbit pushes them slightly past
    /// the device edges — the "bleed" is intentional.
    private var satelliteSize: CGFloat { size }
    private var orbitRadius: CGFloat   { size * position.orbitRadiusFactor }

    var body: some View {
        cardsCanvas
            .offset(
                x: canvasSavedOffset.width + canvasDragTranslation.width,
                y: canvasSavedOffset.height + canvasDragTranslation.height
            )
            .gesture(canvasDragGesture)
            // No `.clipped()` — satellites are allowed to bleed off the
            // device edges when expanded. That's the intended "scattered"
            // feel.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { dismissToolbarIfNeeded() }
            .overlay(alignment: .bottom) {
                toolbarDock
            }
    }

    private var toolbarDock: some View {
        VStack(spacing: 16) {
            if controlBarExpanded || showCode {
                MotionControlBar(
                    preset: $preset,
                    config: $config,
                    position: $position,
                    isExpanded: $controlBarExpanded,
                    showCode: $showCode,
                    onCollapse: collapseControlBar
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            HStack(spacing: 8) {
                Spacer()
                customizeFAB
                toolsFAB
            }
        }
        .padding(.horizontal, StudioLayout.horizontalPadding)
        .padding(.bottom, StudioLayout.horizontalPadding)
        .frame(maxWidth: .infinity, alignment: .bottomTrailing)
    }

    /// Tools FAB — right edge of the sibling row. Toggles the code
    /// view; second tap restores the toolbox to its pre-code-view
    /// state (collapsed / specs panel).
    private var toolsFAB: some View {
        StudioCircleFAB(
            symbol: "wrench.and.screwdriver.fill",
            isActive: showCode,
            accessibilityLabel: showCode ? "Close generated code" : "Open generated code"
        ) {
            if showCode {
                dismissCodeView()
            } else {
                withAnimation(toolboxMorphAnim) {
                    expandedStateBeforeCode = controlBarExpanded
                    controlBarExpanded = true
                    showCode = true
                }
            }
        }
    }

    /// Customize FAB — left of the tools FAB. Toggles the specs panel.
    private var customizeFAB: some View {
        let isActive = controlBarExpanded && !showCode
        return StudioCircleFAB(
            symbol: "slider.horizontal.3",
            isActive: isActive,
            accessibilityLabel: isActive ? "Close customize panel" : "Open customize panel"
        ) {
            withAnimation(toolboxMorphAnim) {
                if showCode {
                    showCode = false
                    controlBarExpanded = expandedStateBeforeCode
                } else {
                    controlBarExpanded.toggle()
                }
            }
        }
    }

    /// Closes the toolbox's code view and restores `controlBarExpanded`
    /// to whatever it was right before the user opened code view.
    private func dismissCodeView() {
        withAnimation(toolboxMorphAnim) {
            showCode = false
            controlBarExpanded = expandedStateBeforeCode
        }
    }

    private func collapseControlBar() {
        withAnimation(toolboxMorphAnim) {
            showCode = false
            controlBarExpanded = false
        }
    }

    private func dismissToolbarIfNeeded() {
        guard controlBarExpanded || showCode else { return }
        collapseControlBar()
    }

    /// The draggable bubble composition. Satellites wrapped in a
    /// `TimelineView` so the optional auto-spin (`position.spinning`)
    /// can rotate the orbit positions every frame without rebuilding
    /// the main card.
    @ViewBuilder
    private var cardsCanvas: some View {
        ZStack {
            TimelineView(.animation(paused: !(position.spinning && expanded))) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let spinAngle: Double = {
                    guard position.spinning, expanded,
                          position.spinPeriod > 0.01
                    else { return 0 }
                    let phase = t.truncatingRemainder(dividingBy: position.spinPeriod) / position.spinPeriod
                    return phase * .pi * 2
                }()

                // ZStack — without this, SwiftUI lays out the 6 cards
                // vertically (TimelineView's content is an implicit
                // VStack), making the canvas occupy the full screen
                // and occluding the control bar at the bottom.
                ZStack {
                    ForEach(0..<6, id: \.self) { i in
                        let baseAngle = Double(i) * (.pi * 2 / 6) - .pi / 2
                        let angle = baseAngle + Self.angleJitter[i] + spinAngle
                        let jitter = Self.positionJitter[i]
                        let dx = orbitRadius * CGFloat(cos(angle)) + jitter.0
                        let dy = orbitRadius * CGFloat(sin(angle)) + jitter.1

                        let baseTilt     = Self.satelliteRotation[i % Self.satelliteRotation.count]
                        let restRotation = Double(position.tiltMagnitude) * baseTilt
                        let scrambleBase = Self.scrambleRotation[i % Self.scrambleRotation.count]
                        let scrambleAdd  = scrambleBase * config.scrambleFactor

                        IdleBreathingCard(
                            place: satellitePlace(at: i),
                            size: satelliteSize,
                            rotation: expanded ? restRotation : restRotation + scrambleAdd,
                            breathPhase: Double(i) * 0.83,
                            period: position.idlePeriod
                        )
                        .offset(x: expanded ? dx : 0, y: expanded ? dy : 0)
                        .scaleEffect(expanded ? 1.0 : 0.05)
                        .opacity(expanded ? 1.0 : 0.0)
                        .animation(config.animation(cardIndex: i), value: expanded)
                    }
                }
            }

            IdleBreathingCard(
                place: place,
                size: size,
                rotation: rotation,
                breathPhase: 0,
                period: position.idlePeriod
            )
            .scaleEffect(pop)
            .onTapGesture { handleTap() }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(expanded ? "Collapse" : "Expand")
        }
    }

    /// Drag gesture for the cards canvas. `minimumDistance: 10` so a
    /// short tap on the main card still toggles expand/collapse
    /// without accidentally starting a drag.
    private var canvasDragGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .updating($canvasDragTranslation) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                canvasSavedOffset.width  += value.translation.width
                canvasSavedOffset.height += value.translation.height
            }
    }

    private func handleTap() {
        // Light haptic — same tone on every tap, both directions.
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        #endif

        // (1) Satellites — just flip the state. Each satellite's own
        //     `.animation(cardAnim, value: expanded)` modifier carries
        //     its per-card delay, so the burst CASCADES instead of
        //     all 6 cards jumping at once. Same cascade on close.
        expanded.toggle()

        // (2) Main breath/pop — inhale, then exhale back on the
        //     inhale's natural completion (no DispatchQueue delay).
        withAnimation(inhaleAnimation) {
            pop = popDepth
        } completion: {
            withAnimation(exhaleAnimation) {
                pop = 1.0
            }
        }
    }

    // Slightly chaotic hex — angle wobble breaks the perfect 60° ring,
    // position jitter scatters the cards off their orbit centres, and
    // a wider rotation range tilts each card more dramatically.
    private static let angleJitter: [Double] =
        [-0.09, 0.06, -0.07, 0.08, -0.05, 0.07]
    private static let positionJitter: [(CGFloat, CGFloat)] =
        [(20, -2), (10, 7), (-6, 9), (12, -4), (-11, 5), (7, -9)]
    private static let satelliteRotation: [Double] =
        [10, 10, -8, 16, -12, 9]
    /// Extra rotation each card carries WHILE collapsed. As the card
    /// flies out, this extra rotation animates away — visually, the
    /// card "untangles" itself into its rest tilt during transit.
    /// Reverses on close → cards re-scramble as they fly back in.
    private static let scrambleRotation: [Double] =
        [-22, 18, -16, 26, -20, 14]

    /// Resolves the `Place` shown in satellite slot `i`. If the caller
    /// passed a custom `satellites` array with at least 6 entries we
    /// use that — otherwise we synthesise a stand-in from `Photos.pool`
    /// so the card never ends up blank.
    private func satellitePlace(at i: Int) -> Place {
        if let satellites, satellites.count >= 6 {
            return satellites[i]
        }
        return Self.fallbackSatellitePlace(for: i, parentID: place.id)
    }

    private static func fallbackSatellitePlace(for i: Int, parentID: String) -> Place {
        Place(
            id: "\(parentID)-sat-\(i)",
            title: "",
            subtitle: "",
            imageURL: Photos.url(seed: 2001 + i * 137),
            stays: 0,
            rating: 0,
            category: "satellite"
        )
    }
}

/// `BubbleView` wrapped in a `TimelineView`-driven sin oscillator that
/// gives the card a continuous "idle breath" — scale oscillates
/// ±2 % around 1.0 on a configurable cycle. `breathPhase` shifts each
/// card's position in the cycle so a group of cards don't breathe in
/// unison. `period` is exposed so the Position panel can tune it.
private struct IdleBreathingCard: View {
    let place: Place
    let size: CGFloat
    let rotation: Double
    let breathPhase: Double
    /// Full breath cycle (inhale + exhale) in seconds.
    var period: Double = 5.0

    /// Peak deviation from 1.0 — ±2 % is gentle but visible at this
    /// card size.
    private let amplitude: CGFloat = 0.02

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate + breathPhase
            let phase = t.truncatingRemainder(dividingBy: period) / period
            let scale = 1.0 + amplitude * CGFloat(sin(phase * .pi * 2))

            BubbleView(place: place, size: size, rotation: rotation)
                .scaleEffect(scale)
        }
    }
}

// MARK: - Motion presets
//
// Five distinct motion proposals for the satellite expand/contract.
// Each preset bundles its own animation curve, per-card stagger, and
// scramble-rotation intensity, so swapping the preset meaningfully
// changes the personality of the burst — not just the timing.
//
//   · `cascade` — staggered, sleek, soft overshoot. "Shuffling into
//     the grid" feel. Default.
//   · `burst`   — all 6 cards exit simultaneously on a snappy bouncy
//     spring, with double the scramble rotation. Energetic explosion.
//   · `drift`   — long ease-in-out curve (no spring), generous
//     stagger, almost no scramble rotation. Floaty, dreamy.
//   · `spiral`  — sequential stagger with REVERSED scramble rotation,
//     medium-bouncy spring. Cards whip in the opposite direction of
//     their rest tilt → vortex / pinwheel feel.
//   · `snap`    — no stagger, very fast snappy spring, zero scramble.
//     Crisp, instant, almost teleport-into-place.

enum MotionPreset: String, CaseIterable, Identifiable {
    case cascade
    case burst
    case drift
    case spiral
    case snap

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cascade: return "Cascade"
        case .burst:   return "Burst"
        case .drift:   return "Drift"
        case .spiral:  return "Spiral"
        case .snap:    return "Snap"
        }
    }

    /// The starting parameters for this preset. Tapping a chip in the
    /// control bar resets the live `MotionConfig` to these values.
    func defaultConfig() -> MotionConfig {
        switch self {
        case .cascade:
            return MotionConfig(response: 0.85, damping: 0.72,
                                stagger: 0.05, scrambleFactor: 1.0,
                                curve: .spring)
        case .burst:
            return MotionConfig(response: 0.45, damping: 0.58,
                                stagger: 0.0, scrambleFactor: 2.0,
                                curve: .spring)
        case .drift:
            return MotionConfig(response: 1.4,  damping: 1.0,
                                stagger: 0.12, scrambleFactor: 0.3,
                                curve: .easeInOut)
        case .spiral:
            return MotionConfig(response: 0.70, damping: 0.65,
                                stagger: 0.07, scrambleFactor: -1.8,
                                curve: .spring)
        case .snap:
            return MotionConfig(response: 0.28, damping: 0.95,
                                stagger: 0.0, scrambleFactor: 0.0,
                                curve: .spring)
        }
    }
}

// MARK: - Live motion config
//
// Mutable bag of animation parameters driven by the slider panel.
// Replaces the hard-coded per-preset values so the studio can tune
// the burst live. Initialised from `MotionPreset.defaultConfig()`
// when a chip is tapped, then freely tweaked from the sliders.

struct MotionConfig: Equatable {
    enum Curve: String, CaseIterable, Equatable {
        case spring
        case easeInOut

        var label: String {
            switch self {
            case .spring:    return "Spring"
            case .easeInOut: return "Ease"
            }
        }
    }

    /// Spring response (or, for ease curves, total duration).
    var response: Double
    /// Spring damping fraction. Ignored for ease curves.
    var damping: Double
    /// Per-card stagger delay in seconds. 0 = all cards animate
    /// simultaneously.
    var stagger: Double
    /// Multiplier on each satellite's base scramble rotation while
    /// collapsed. Negative values reverse the spin direction.
    var scrambleFactor: CGFloat
    var curve: Curve

    func animation(cardIndex: Int) -> Animation {
        let base: Animation
        switch curve {
        case .spring:
            base = .spring(response: response, dampingFraction: damping)
        case .easeInOut:
            base = .easeInOut(duration: response)
        }
        return base.delay(Double(cardIndex) * stagger)
    }
}

// MARK: - Live position config
//
// Sibling of `MotionConfig`. Holds layout / idle-state parameters
// for the bubble composition — orbit radius, card tilt magnitude,
// idle breath speed, and optional auto-spin of the satellite ring.
// Independent of `MotionConfig` so tweaks to the layout don't
// disturb the expand/contract animation specs.

struct PositionConfig: Equatable {
    /// Multiplier on `size` used as the satellite orbit radius.
    /// 1.0 = orbit centre sits exactly at one card-height from the
    /// main; 1.2 = the original push-off-the-edge default.
    var orbitRadiusFactor: CGFloat
    /// Scales the base per-card tilt rotation. 0 = every card is
    /// perfectly upright at rest; 2 = double tilt.
    var tiltMagnitude: CGFloat
    /// Seconds per idle-breath cycle on every card.
    var idlePeriod: Double
    /// Toggles continuous orbit rotation of the satellite ring
    /// around the main while expanded.
    var spinning: Bool
    /// Seconds per full 360° orbit when `spinning == true`.
    var spinPeriod: Double

    static let defaults = PositionConfig(
        orbitRadiusFactor: 1.20,
        tiltMagnitude: 1.0,
        idlePeriod: 5.0,
        spinning: false,
        spinPeriod: 8.0
    )
}

// MARK: - Motion control bar (Liquid Glass · draggable · expandable)
//
// Floating Liquid Glass surface that holds:
//   · top row of 5 preset chips (Cascade / Burst / Drift / Spiral /
//     Snap) — tapping one resets `config` to its defaults;
//   · chevron toggle that expands a slider panel for fine-tuning the
//     four animation parameters (response, damping, stagger,
//     scramble) and switching the curve type between Spring / Ease;
//   · drag handle (a small grabber capsule above the chip row) that
//     lets the user reposition the whole bar anywhere on the stage
//     without conflicting with the chip taps or slider drags.

private struct MotionControlBar: View {
    @Binding var preset: MotionPreset
    @Binding var config: MotionConfig
    @Binding var position: PositionConfig
    /// Owned by `ExpandingBubbleCard` so the external tools FAB can
    /// jump straight into code view (open + flip showCode together).
    @Binding var isExpanded: Bool
    @Binding var showCode: Bool
    let onCollapse: () -> Void

    enum SpecCategory: String, CaseIterable, Identifiable {
        case position
        case motion
        var id: String { rawValue }
        var label: String {
            switch self {
            case .position: return "Position"
            case .motion:   return "Motion"
            }
        }
    }

    @State private var category: SpecCategory = .position
    @State private var didCopy: Bool = false

    @Namespace private var pillSpace
    @Namespace private var categorySpace

    private let presetSwitchAnim: Animation =
        .spring(response: 0.42, dampingFraction: 0.82)
    private let expandAnim: Animation =
        .spring(response: 0.45, dampingFraction: 0.85)

    /// Toolbox surface tokens — single source of truth so every
    /// surface inside the bar stays on the same Liquid Glass look,
    /// mirroring `SearchModalView`'s `NavButtonGlass`:
    /// iOS 26 → real `.glassEffect(.clear.interactive())`,
    /// older → `.ultraThinMaterial`.
    private let surfaceCornerRadius: CGFloat = 32
    private let innerCornerRadius: CGFloat   = 18
    /// Very faint dark wash used for the unselected category-switcher
    /// background track.
    private let inkSoft: Color  = Color.black.opacity(0.08)

    var body: some View {
        VStack(spacing: 12) {
            chipRow
            slidersPanel
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background {
            liquidGlassRoundedRect(
                cornerRadius: surfaceCornerRadius,
                tint: 0          // pure glass — no white wash on the toolbar bg
            )
        }
        // Clip content to the toolbox shape so the slider panel's
        // slide-in transition stays INSIDE the bg — without this the
        // panel briefly renders below the toolbox bounds during the
        // move-from-bottom animation and overlaps the row underneath.
        .clipShape(RoundedRectangle(cornerRadius: surfaceCornerRadius,
                                    style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 10)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Motion controls")
    }

    // MARK: - Liquid Glass surface helper
    //
    // Matches the `SampleGlassPill` style — `.regular.interactive()`
    // so the toolbox carries the same fuller Liquid Glass material
    // as the sample pill, not the thinner `.clear` variant.
    //   · iOS 26 → `.glassEffect(.regular.interactive(), in: shape)`.
    //   · older  → `.ultraThinMaterial` directly.
    // `tint == 0` → pure glass (toolbox bg). `tint > 0` → white wash
    // overlay (not currently used outside the toolbox bg, but kept
    // available so the helper stays general).

    @ViewBuilder
    private func liquidGlassRoundedRect(cornerRadius: CGFloat, tint: Double) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26.0, *) {
            if tint > 0 {
                shape
                    .fill(.clear)
                    .glassEffect(.regular.interactive().tint(.white.opacity(tint)), in: shape)
            } else {
                shape
                    .fill(.clear)
                    .glassEffect(.regular.interactive(), in: shape)
            }
        } else {
            shape
                .fill(.ultraThinMaterial)
                .overlay(shape.fill(Color.white.opacity(tint)))
        }
    }

    // MARK: - Chip row (5 presets)

    private var chipRow: some View {
        HStack(spacing: 4) {
            ForEach(MotionPreset.allCases) { p in
                chip(for: p)
            }
        }
    }

    @ViewBuilder
    private func chip(for p: MotionPreset) -> some View {
        let isSelected = (preset == p)

        Text(p.label)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(isSelected ? Aurora.ink : Aurora.ink.opacity(0.62))
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background {
                if isSelected {
                    selectedPillBg
                        .matchedGeometryEffect(id: "pill", in: pillSpace)
                } else {
                    // Unselected — same surface at 50 % so the chip
                    // still reads as a pill but recedes visually
                    // behind the active one.
                    selectedPillBg
                        .opacity(0.5)
                }
            }
            .contentShape(Capsule())
            // Double-tap = open / close the customize panel. Single
            // tap = select the preset and reset code-view mode.
            // SwiftUI evaluates the higher-count gesture first, so
            // a quick second tap reaches the double-tap handler
            // before the single-tap one fires.
            .onTapGesture(count: 2) {
                withAnimation(expandAnim) { isExpanded.toggle() }
            }
            .onTapGesture(count: 1) {
                withAnimation(presetSwitchAnim) {
                    preset = p
                    config = p.defaultConfig()
                    showCode = false
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(p.label)
            .accessibilityHint("Single tap selects, double tap opens controls")
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Customize panel
    //
    // Below the chip-row divider when expanded. Two sub-modes:
    //   · specs view  — category switcher + slider tray + small
    //                   circular copy affordance.
    //   · code view   — generated SwiftUI snippet shown in a dark
    //                   tray + full-width "Copy SwiftUI code" CTA.
    // Swap between them by tapping the copy affordance; switching
    // preset / category resets back to the specs view.

    private var slidersPanel: some View {
        VStack(spacing: 12) {
            if showCode {
                codeBox
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                copyAffordance
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                categorySwitcher
                Group {
                    switch category {
                    case .motion:   motionSliders
                    case .position: positionSliders
                    }
                }
                .transition(.opacity)
                .padding(12)
                .background {
                    // Slider tray — pure `.ultraThinMaterial`, no
                    // black overlay. Reads brighter / whiter than
                    // before so the dark slider tracks stand out on
                    // their own.
                    RoundedRectangle(cornerRadius: innerCornerRadius,
                                     style: .continuous)
                        .fill(.ultraThinMaterial)
                }
            }
        }
        .padding(.top, 4)
        .padding(.horizontal, 4)
    }

    private var categorySwitcher: some View {
        HStack(spacing: 4) {
            ForEach(SpecCategory.allCases) { c in
                categoryChip(c)
            }
        }
        .padding(3)
        .background(
            Capsule().fill(inkSoft)
        )
    }

    @ViewBuilder
    private func categoryChip(_ c: SpecCategory) -> some View {
        let isOn = (category == c)
        Button {
            withAnimation(presetSwitchAnim) {
                category = c
                showCode = false
            }
        } label: {
            Text(c.label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isOn ? Aurora.ink : Aurora.ink.opacity(0.55))
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background {
                    if isOn {
                        selectedPillBg
                            .matchedGeometryEffect(id: "category-pill", in: categorySpace)
                    } else {
                        selectedPillBg.opacity(0.5)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Motion sliders

    private var motionSliders: some View {
        VStack(spacing: 10) {
            // Curve picker — Spring vs Ease. Aligned to the left
            // edge of the panel (Spacer at end keeps the pills
            // tight to the label, not stretched across the row).
            HStack(spacing: 6) {
                paramLabel("Curve")
                ForEach(MotionConfig.Curve.allCases, id: \.self) { c in
                    curvePill(c)
                }
                Spacer(minLength: 0)
            }

            paramSlider(label: "Response",
                        value: Binding(
                            get: { config.response },
                            set: { config.response = $0 }
                        ),
                        range: 0.10...2.00,
                        format: "%.2f")

            paramSlider(label: "Damping",
                        value: Binding(
                            get: { config.damping },
                            set: { config.damping = $0 }
                        ),
                        range: 0.40...1.00,
                        format: "%.2f")

            paramSlider(label: "Stagger",
                        value: Binding(
                            get: { config.stagger },
                            set: { config.stagger = $0 }
                        ),
                        range: 0.00...0.25,
                        format: "%.2fs")

            paramSlider(label: "Scramble",
                        value: Binding(
                            get: { Double(config.scrambleFactor) },
                            set: { config.scrambleFactor = CGFloat($0) }
                        ),
                        range: -3.0...3.0,
                        format: "%.1f")
        }
    }

    // MARK: - Position sliders

    private var positionSliders: some View {
        VStack(spacing: 10) {
            paramSlider(label: "Orbit",
                        value: Binding(
                            get: { Double(position.orbitRadiusFactor) },
                            set: { position.orbitRadiusFactor = CGFloat($0) }
                        ),
                        range: 0.6...2.4,
                        format: "%.2fx")

            paramSlider(label: "Tilt",
                        value: Binding(
                            get: { Double(position.tiltMagnitude) },
                            set: { position.tiltMagnitude = CGFloat($0) }
                        ),
                        range: 0.0...2.5,
                        format: "%.2fx")

            paramSlider(label: "Idle speed",
                        value: Binding(
                            // Invert so right = faster.
                            get: { 12.0 - position.idlePeriod },
                            set: { position.idlePeriod = max(0.4, 12.0 - $0) }
                        ),
                        range: 0.0...11.6,
                        format: "%.1fHz")

            // Spinning toggle.
            HStack(spacing: 8) {
                paramLabel("Spin")
                Toggle("", isOn: Binding(
                    get: { position.spinning },
                    set: { position.spinning = $0 }
                ))
                .labelsHidden()
                // Soft 20 % black tint to match the slider tracks.
                .tint(Color.black.opacity(0.20))
                Spacer()
                Text(position.spinning ? "ON" : "OFF")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(Aurora.ink.opacity(0.7))
                    .frame(width: 50, alignment: .trailing)
            }

            paramSlider(label: "Spin speed",
                        value: Binding(
                            // Invert so right = faster.
                            get: { 22.0 - position.spinPeriod },
                            set: { position.spinPeriod = max(1.0, 22.0 - $0) }
                        ),
                        range: 0.0...21.0,
                        format: "%.1fHz")
                .opacity(position.spinning ? 1.0 : 0.45)
                .disabled(!position.spinning)
        }
    }

    @ViewBuilder
    private func paramLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Aurora.ink.opacity(0.55))
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(width: 70, alignment: .leading)
    }

    @ViewBuilder
    private func curvePill(_ c: MotionConfig.Curve) -> some View {
        let isOn = (config.curve == c)
        Button {
            withAnimation(presetSwitchAnim) {
                config.curve = c
            }
        } label: {
            Text(c.label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isOn ? Aurora.ink : Aurora.ink.opacity(0.55))
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background {
                    if isOn {
                        selectedPillBg
                    } else {
                        selectedPillBg.opacity(0.5)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func paramSlider(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        format: String
    ) -> some View {
        HStack(spacing: 8) {
            paramLabel(label)

            Slider(value: value, in: range)
                // Soft 20 % black tint instead of solid ink — matches
                // the lighter "more white" slider tray bg.
                .tint(Color.black.opacity(0.20))

            Text(String(format: format, value.wrappedValue))
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(Aurora.ink.opacity(0.70))
                .frame(width: 50, alignment: .trailing)
        }
    }

    // MARK: - Copy affordance (morphing circle ↔ wide CTA)
    //
    // Initial state — a 24×24 circle with a copy icon, parked on the
    // right edge of the panel. Tap it once: it morphs horizontally
    // into a full-width "Copy SwiftUI code" CTA, the slider tray is
    // replaced by the generated code box, AND the snippet is written
    // to the clipboard so the very first tap already delivers value.
    // Subsequent taps re-copy and flash a "Copied!" confirmation.

    /// Only renders in code view. Single full-width "Copy SwiftUI
    /// code" CTA — same horizontal extent as the code box above it.
    /// Tools FAB outside the toolbox handles dismissing the code
    /// view, so no companion button is needed here.
    private var copyAffordance: some View {
        Button {
            performCopy()
        } label: {
            Text(didCopy ? "Copied" : "Copy SwiftUI code")
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(Aurora.ink)
                .frame(height: 36)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .background {
                    selectedPillBg
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Copy SwiftUI code")
    }

    /// "Ultra thin material + 70 % white" surface used by every
    /// SELECTED pill / CTA inside the toolbox. Pure material — no
    /// `.glassEffect` involved, because the user's spec for the
    /// selected state is explicitly material-thin-white, not glass.
    @ViewBuilder
    private var selectedPillBg: some View {
        Capsule()
            .fill(.ultraThinMaterial)
            .overlay(Capsule().fill(Color.white.opacity(0.70)))
    }

    /// Renders the generated SwiftUI specs in a monospaced "console"
    /// tray. Same Liquid Glass surface as the slider tray so the two
    /// views feel like swappable lenses of the same panel.
    private var codeBox: some View {
        ScrollView {
            Text(generatedSpecsCode())
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Aurora.ink.opacity(0.88))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .textSelection(.enabled)
        }
        .frame(maxHeight: 200)
        .background {
            liquidGlassRoundedRect(cornerRadius: innerCornerRadius, tint: 0)
        }
    }

    private func performCopy() {
        #if canImport(UIKit)
        UIPasteboard.general.string = generatedSpecsCode()
        #endif
        withAnimation(presetSwitchAnim) { didCopy = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(presetSwitchAnim) { didCopy = false }
        }
    }

    /// Produces a self-contained SwiftUI snippet with both the motion
    /// curve and the position parameters so a designer / engineer can
    /// paste it straight into their project. The snippet uses neutral
    /// identifiers (`burstAnimation`, `cardStagger`, `orbitRadius`,
    /// …) so it's easy to adapt to any expanding-card layout.
    private func generatedSpecsCode() -> String {
        let curveLine: String
        switch config.curve {
        case .spring:
            curveLine = String(
                format: "let burstAnimation: Animation = .spring(response: %.2f, dampingFraction: %.2f)",
                config.response, config.damping
            )
        case .easeInOut:
            curveLine = String(
                format: "let burstAnimation: Animation = .easeInOut(duration: %.2f)",
                config.response
            )
        }

        let stagger      = String(format: "%.2f", config.stagger)
        let scramble     = String(format: "%.2f", Double(config.scrambleFactor))
        let orbitFactor  = String(format: "%.2f", Double(position.orbitRadiusFactor))
        let tilt         = String(format: "%.2f", Double(position.tiltMagnitude))
        let idlePeriod   = String(format: "%.2f", position.idlePeriod)
        let spinning     = position.spinning ? "true" : "false"
        let spinPeriod   = String(format: "%.2f", position.spinPeriod)
        let preset       = self.preset.label

        return """
        // Generated by Component Studio · preset: \(preset)
        // Drop this into any SwiftUI view with a `place` + 6 satellites.

        // — Motion specs —
        \(curveLine)
        let cardStagger: TimeInterval = \(stagger)
        let scrambleFactor: CGFloat   = \(scramble)

        // Per satellite (i = 0..<6):
        //   .offset(x: expanded ? dx : 0, y: expanded ? dy : 0)
        //   .scaleEffect(expanded ? 1.0 : 0.05)
        //   .opacity(expanded ? 1.0 : 0.0)
        //   .animation(burstAnimation.delay(Double(i) * cardStagger),
        //              value: expanded)

        // — Position specs —
        let orbitRadiusFactor: CGFloat = \(orbitFactor)  // × bubbleHeight
        let tiltMagnitude: CGFloat     = \(tilt)
        let idlePeriod: Double         = \(idlePeriod)   // seconds / breath
        let spinning: Bool             = \(spinning)
        let spinPeriod: Double         = \(spinPeriod)   // seconds / orbit
        """
    }
}
