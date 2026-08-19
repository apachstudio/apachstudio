import SwiftUI

/// The floating bottom search bar — squircle container with a placeholder on
/// top, a filled dark send button on the right, and a two-mode toggle below
/// ("AI mode" / "Standard"). Real Liquid Glass background with the animated
/// snake stroke + AI aura, kept in sync.
struct SearchBoxView: View {
    enum SearchMode { case ai, standard }

    private let collapsedHeight: CGFloat = 58
    private let expandedHeight: CGFloat = 116
    /// Half the collapsed height → at-rest bar reads as a full pill /
    /// capsule (100% rounding). When focused/expanded to `expandedHeight`
    /// the corners stay at this radius, which still reads as a soft
    /// rounded card and avoids the corners morphing during focus.
    private var cornerRadius: CGFloat { collapsedHeight / 2 }
    /// Typed text + placeholder font size — 15pt (10% smaller than the
    /// earlier 17pt). Reads as a compact input chip, in line with the
    /// nav-bar search field on the results page.
    private let inputFontSize: CGFloat = 15
    /// Vertical gap between the input row and the mode pills row when
    /// the bar is focused. Bigger than before so the pills aren't
    /// crowding the typed query.
    private let inputToPillsGap: CGFloat = 18

    private let phrases = [
        "Find a hidden lake…",
        "Show me a misty grove…",
        "Drift toward the aurora…",
        "Search 10,000 calm places…",
    ]

    /// Bound to the parent so dismissing the results modal can clear the
    /// query — the pill comes back to its default empty state.
    @Binding var text: String

    /// Fired when the user submits a non-empty query (return key or send button).
    var onSubmit: (String) -> Void = { _ in }

    /// Component Studio: open already focused/expanded for screen recording.
    var initialFocused: Bool = false

    /// Live motion / aura knobs from the Spec Toolbox.
    var motionSpecs: SearchBoxSpecs = SearchBoxSpecs(
        ComponentSpecState(defaults: StudioItem.searchPillRest.specDefaults),
        sheet: StudioItem.searchPillRest.specSheet!
    )

    @FocusState private var focused: Bool
    /// Visual "open" state, decoupled from keyboard focus. Latches true once
    /// the bar is focused and stays open even if the keyboard is dismissed
    /// (e.g. tapping the blank canvas) — so the bar doesn't collapse back.
    /// Only `submit()` returns it to the collapsed rest state.
    @State private var expanded = false
    @State private var mode: SearchMode = .ai
    @State private var typed = ""
    @State private var phraseIndex = 0
    @State private var charIndex = 0
    @State private var deleting = false
    @State private var caretOn = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: inputToPillsGap) {
            inputRow
            if expanded {
                bottomRow
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity.combined(with: .move(edge: .bottom))
                        )
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, expanded ? 10 : 14)
        .frame(height: expanded ? expandedHeight : collapsedHeight)
        .modifier(LiquidGlassContainer(focused: expanded, cornerRadius: cornerRadius))
        .overlay(aiAura)
        // Snake only renders in AI mode — Standard is fully neutral.
        .overlay {
            if mode == .ai { snakeStroke }
        }
        // Clear (X) sits at the top-trailing corner of the box, above all
        // glass surfaces — not inline with the input row. Visible only
        // while focused with text typed.
        .overlay(alignment: .topTrailing) { clearButton }
        // The pill's geometric handoff to the full-screen search results is
        // declared OUTSIDE this view (BubbleCloudView wraps it with
        // `.matchedTransitionSource(id: "search", in: ns)` so the system's
        // `.zoom` navigation transition can interpolate position, size and
        // corner radius automatically — Photos / App Library style).
        .opacity(expanded ? 0.95 : 0.78)
        .simultaneousGesture(
            TapGesture().onEnded { focused = true }
        )
        .scaleEffect(expanded ? motionSpecs.focusScale : 1.0)
        // Smooth spring drives container height, bottom-row reveal, opacity,
        // and scale — all in sync when the bar opens / closes.
        .animation(
            .spring(response: motionSpecs.focusResponse, dampingFraction: motionSpecs.focusDamping),
            value: expanded
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.78), value: mode)
        // Gaining keyboard focus latches the bar open. Losing focus (tapping
        // the blank canvas) does NOT collapse it — only `submit()` does.
        .onChange(of: focused) { _, isFocused in
            if isFocused { expanded = true }
        }
        .task { await runTypewriter() }
        .task { await blinkCaret() }
        .onAppear {
            if initialFocused {
                focused = true
                expanded = true
            }
        }
    }

    // MARK: - Top row: placeholder/input

    /// AI mode → AI gradient. Standard mode → black @ 40%.
    private var inputForeground: AnyShapeStyle {
        mode == .ai
            ? AnyShapeStyle(Aurora.AI.still)
            : AnyShapeStyle(Color.black.opacity(0.40))
    }

    /// Palette for snake stroke + aura. AI mode = full AI palette. Standard
    /// mode = pure white/gray scale (no color).
    private var currentPalette: [Color] {
        mode == .ai
            ? Aurora.AI.stops
            : [Color.white, Color.gray.opacity(0.4), Color.gray.opacity(0.7)]
    }

    /// Cursor tint — always black @ 40%, independent of mode.
    private var cursorTint: Color { .black.opacity(0.40) }

    private var inputRow: some View {
        ZStack(alignment: .leading) {
            if !expanded && text.isEmpty {
                HStack(spacing: 0) {
                    Text(typed)
                    Text("▏").opacity(caretOn ? 1 : 0)
                }
                .font(AppFont.manrope(inputFontSize))
                .foregroundStyle(inputForeground)
                .lineLimit(1)
            }
            TextField("", text: $text)
                .focused($focused)
                .submitLabel(.search)
                .onSubmit { submit() }
                // Lowercase only — match the all-lowercase placeholder
                // ("find a hidden lake…") and let the user type their
                // own query without the iOS auto-capitalize jumping in.
                .textInputAutocapitalization(.never)
                .font(AppFont.manrope(inputFontSize))
                .foregroundStyle(typedTextStyle)
                .tint(cursorTint)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
    }

    /// Top-trailing clear (X) — sits 16pt from the box's top-right
    /// corner. Visible only while the bar is focused with text typed.
    /// Tap clears the field and keeps focus so the user keeps typing.
    @ViewBuilder
    private var clearButton: some View {
        if expanded && !text.isEmpty {
            Button {
                text = ""
                focused = true
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Aurora.ink.opacity(0.2))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 16)
            .padding(.trailing, 16)
            .accessibilityLabel("Clear search")
            .transition(.opacity)
        }
    }

    /// Color of the typed query text, by state:
    ///   • Unfocused          → ink @ 80% (calm rest state).
    ///   • Focused, AI mode   → solid violet from the AI palette — the
    ///                          "AI is on" cue that matches the aura/snake.
    ///   • Focused, Standard  → ink @ 50% (no color, regular search).
    ///
    /// IMPORTANT: must be a SOLID color, never a gradient. An editable
    /// `TextField` is backed by UITextField and does NOT render a
    /// ShapeStyle gradient as its live text color — the text comes out
    /// invisible. (A `Text` renders gradients fine, which is why the
    /// placeholder can still use `Aurora.AI.still`.) Using a gradient
    /// here was the "I type but nothing appears" bug.
    private var typedTextStyle: AnyShapeStyle {
        if !focused {
            return AnyShapeStyle(Aurora.ink.opacity(0.80))
        }
        return mode == .ai
            ? AnyShapeStyle(Aurora.aiTextSolid)
            : AnyShapeStyle(Aurora.ink.opacity(0.50))
    }

    /// Minimal arrow.up — `Aurora.ink @ 40%` icon on a sutil
    /// ink-tinted circle (`Aurora.ink @ 6%`). The circle gives the
    /// button a defined target on the bar without competing visually
    /// with the chips next to it. Height matches the Standard chip
    /// selected pill (~30pt).
    private var sendButton: some View {
        Button(action: submit) {
            Image(systemName: "arrow.up")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Aurora.ink.opacity(0.4))
                .frame(width: 30, height: 30)
                .background(Circle().fill(Aurora.ink.opacity(0.06)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Submit search")
    }

    // MARK: - Bottom row: mode toggle + send button (only when text exists)

    private var bottomRow: some View {
        HStack(spacing: 8) {
            modeChip(.ai, label: "AI mode", icon: "sparkles")
            modeChip(.standard, label: "Standard", icon: "magnifyingglass")
            Spacer(minLength: 0)
            sendButton
        }
    }

    @ViewBuilder
    private func modeChip(_ target: SearchMode, label: String, icon: String) -> some View {
        let selected = mode == target
        Button {
            mode = target
            // Keep the bar focused — without this, switching from Standard
            // back to AI was sometimes triggering focus loss because the chip
            // tap registered as "outside the TextField."
            focused = true
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(AppFont.manrope(13, .medium, relativeTo: .footnote))
            }
            .foregroundStyle(modeForeground(target: target, selected: selected))
            // Sutil drop shadow on the "Standard" word — slightly more
            // in default (bar collapsed) and reduced when the bar is
            // focused, so the chip lifts off without competing with
            // the typed query.
            .shadow(
                color: .black.opacity(
                    target == .standard
                        ? (expanded ? 0.06 : 0.14)
                        : 0
                ),
                radius: 2,
                y: 1
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background {
                if target == .ai && selected {
                    // AI selected stays prominent — white capsule.
                    Capsule()
                        .fill(Color.white.opacity(0.92))
                        .overlay(Capsule().stroke(Color.white.opacity(0.6), lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.06), radius: 4, y: 1)
                } else if target == .standard {
                    // Standard chip always carries a sutil ink
                    // capsule (matches the send button's opacity), in
                    // both default and focused modes — no dark
                    // selected variant.
                    Capsule().fill(Aurora.ink.opacity(0.06))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) mode")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    /// AI mode chip → always AI gradient (selected or not), so users can
    ///                 always identify the AI option.
    /// Standard chip → solid `Aurora.ink` when selected (over the
    /// always-light ink capsule), dimmed `Aurora.ink @ 55%` when not.
    private func modeForeground(target: SearchMode, selected: Bool) -> AnyShapeStyle {
        switch target {
        case .ai:
            return AnyShapeStyle(Aurora.AI.still)
        case .standard:
            return selected
                ? AnyShapeStyle(Aurora.ink)
                : AnyShapeStyle(Aurora.ink.opacity(0.55))
        }
    }

    // MARK: - AI aura (subtle colored glow under the glass)

    /// Angular gradient capsule that rotates in sync with the snake stroke.
    /// Heavily blurred + low opacity so it reads as a soft glow living inside
    /// the Liquid Glass surface, never as a tint. Freezes under Reduce Motion.
    private var aiAura: some View {
        TimelineView(.animation) { tl in
            let period: Double = expanded
                ? motionSpecs.auraPeriodFocused
                : motionSpecs.auraPeriodRest
            let angle = reduceMotion
                ? 0
                : tl.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: period) / period * 360
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    AngularGradient(
                        gradient: Gradient(colors: currentPalette + [currentPalette[0]]),
                        center: .center,
                        angle: .degrees(angle)
                    )
                )
                .blur(radius: 10)
                .opacity(expanded ? 0.20 : 0.13)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Snake stroke (follows the squircle rim)

    private var snakeStroke: some View {
        TimelineView(.animation) { tl in
            let period: Double = expanded
                ? motionSpecs.auraPeriodFocused
                : motionSpecs.auraPeriodRest
            let angle = reduceMotion
                ? 0
                : tl.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: period) / period * 360
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    AngularGradient(
                        gradient: Gradient(stops: snakeStops(focused: expanded)),
                        center: .center,
                        angle: .degrees(angle)
                    ),
                    lineWidth: expanded ? motionSpecs.snakeWidthFocused : motionSpecs.snakeWidthRest
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(expanded ? 0.10 : 0.06), lineWidth: 0.5)
                )
        }
        .allowsHitTesting(false)
    }

    private func snakeStops(focused: Bool) -> [Gradient.Stop] {
        let colors = currentPalette
        if focused {
            return [
                .init(color: .white,              location: 0.00),
                .init(color: .white.opacity(0.92), location: 0.04),
                .init(color: colors[2],           location: 0.10),
                .init(color: colors[1],           location: 0.18),
                .init(color: colors[0].opacity(0), location: 0.32),
                .init(color: .clear,              location: 1.00),
            ]
        }
        // Rest state — push colors[1] (the violet stop) up to full
        // opacity so the snake clearly reads as TWO colours (pink
        // bleeding into violet) instead of a single pink fade. The
        // band slightly longer too so both stops have room to breathe
        // before fading to clear.
        return [
            .init(color: .white,              location: 0.00),
            .init(color: colors[2],           location: 0.05),  // pink head
            .init(color: colors[1],           location: 0.14),  // violet body, fully opaque
            .init(color: colors[1].opacity(0), location: 0.30),  // violet fades to clear
            .init(color: .clear,              location: 1.00),
        ]
    }

    // MARK: - Submission + animations

    private func submit() {
        let q = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        focused = false
        expanded = false
        onSubmit(q)
    }

    private func blinkCaret() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 480_000_000)
            caretOn.toggle()
        }
    }

    private func runTypewriter() async {
        while !Task.isCancelled {
            if expanded || !text.isEmpty {
                typed = ""
                try? await Task.sleep(nanoseconds: 300_000_000)
                continue
            }
            let full = Array(phrases[phraseIndex])
            if !deleting {
                charIndex = min(charIndex + 1, full.count)
                typed = String(full.prefix(charIndex))
                if charIndex >= full.count {
                    deleting = true
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                } else {
                    try? await Task.sleep(nanoseconds: 55_000_000)
                }
            } else {
                charIndex = max(charIndex - 1, 0)
                typed = String(full.prefix(charIndex))
                if charIndex <= 0 {
                    deleting = false
                    phraseIndex = (phraseIndex + 1) % phrases.count
                    try? await Task.sleep(nanoseconds: 280_000_000)
                } else {
                    try? await Task.sleep(nanoseconds: 28_000_000)
                }
            }
        }
    }
}

/// Liquid Glass squircle container. iOS 26 → real `.glassEffect` (no
/// `.interactive()` — a text-input surface wants the touch to fall
/// straight through to the field). Older → frosted material with a
/// top-light gradient + soft shadow.
private struct LiquidGlassContainer: ViewModifier {
    let focused: Bool
    let cornerRadius: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(
                focused
                    ? .regular.tint(.white.opacity(0.42))
                    : .regular,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        } else {
            content.background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.12), Color.white.opacity(0)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(
                            focused ? Color.white.opacity(0.28) : Color.clear
                        )
                    )
                    .shadow(color: Color(hex: 0x141420, alpha: focused ? 0.16 : 0.10),
                            radius: focused ? 28 : 24, x: 0, y: focused ? 14 : 10)
            }
        }
    }
}
