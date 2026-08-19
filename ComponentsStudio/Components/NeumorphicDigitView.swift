import SwiftUI

// MARK: - Neumorphic productivity icon reveal
//
// Tap the card to cycle through productivity SF Symbols, each embossed into
// the soft neumorphic surface. The (in→out pill) press animation lives in the
// separate `NeumorphicPillsView` component.

struct NeumorphicDigitView: View {
    var title: String = StudioItem.neumorphicDigit.title
    var specs: NeumorphicDigitSpecs = NeumorphicDigitSpecs(
        ComponentSpecState(defaults: StudioItem.neumorphicDigit.specDefaults),
        sheet: StudioItem.neumorphicDigit.specSheet!
    )
    /// When false, renders only the card content (no page chrome) so an
    /// Xcode preview can show the component full-bleed.
    var chrome: Bool = true

    @State private var iconIndex = 0
    @State private var revealToken = 0

    private static let productivityIcons = [
        "note.text", "doc.text.fill", "pencil.and.list.clipboard",
        "tray.full.fill", "folder.fill", "clock.fill", "bell.fill", "chart.bar.fill",
        "target", "square.grid.2x2.fill", "link", "paperplane.fill", "pin.fill",
        "flag.fill", "bookmark.fill", "timer",
    ]

    var body: some View {
        if chrome {
            ShaderPageLayout(title: title, aspectRatio: 1.0) { cardBody }
        } else {
            cardBody
        }
    }

    @ViewBuilder
    private var cardBody: some View {
        // Icon color is the spec color picker; shadow is the dark #242424.
        let palette = NeumorphicPalette.tone(Int(specs.surfaceTone.rounded()))
            .with(iconFill: Color(red: specs.iconColorR, green: specs.iconColorG, blue: specs.iconColorB))
            .with(shadow: Color(red: 0.141, green: 0.141, blue: 0.141))
        ZStack {
            palette.background

            NeumorphicPlainIcon(
                symbol: Self.productivityIcons[iconIndex],
                iconSize: specs.iconSize,
                palette: palette,
                shadowOffsetX: CGFloat(specs.shadowOffsetX),
                shadowOffsetY: CGFloat(specs.shadowOffsetY),
                shadowRadius: CGFloat(specs.shadowRadius),
                shadowOpacity: CGFloat(specs.shadowOpacity),
                iconOpacity: CGFloat(specs.iconOpacity),
                revealDelay: specs.revealDelay,
                motionResponse: specs.motionResponse,
                motionDamping: specs.motionDamping,
                revealToken: revealToken
            )
        }
        .contentShape(Rectangle())
        .onTapGesture { advance() }
    }

    private func advance() {
        let icons = Self.productivityIcons
        guard icons.count > 1 else { return }

        var next = Int.random(in: 0..<icons.count)
        while next == iconIndex {
            next = Int.random(in: 0..<icons.count)
        }
        iconIndex = next
        revealToken += 1
    }
}

// MARK: - Shared neumorphic surface palette

struct NeumorphicPalette {
    let background: Color
    let iconFill: Color
    let shadow: Color
    let highlight: Color

    /// Returns a copy with a different icon color (surface/shadows unchanged).
    func with(iconFill color: Color) -> NeumorphicPalette {
        NeumorphicPalette(background: background, iconFill: color, shadow: shadow, highlight: highlight)
    }

    /// Returns a copy with a different shadow color.
    func with(shadow color: Color) -> NeumorphicPalette {
        NeumorphicPalette(background: background, iconFill: iconFill, shadow: color, highlight: highlight)
    }

    /// Figma pill icon fill (#D3D3DA).
    static let pillIconFill = Color(red: 211 / 255, green: 211 / 255, blue: 218 / 255)

    static func tone(_ index: Int) -> NeumorphicPalette {
        switch index {
        case 1:
            return NeumorphicPalette(
                background: Color(red: 0.07, green: 0.07, blue: 0.08),
                iconFill: Color(red: 0.16, green: 0.16, blue: 0.18),
                shadow: Color.black,
                highlight: Color.white.opacity(0.10)
            )
        case 2:
            return NeumorphicPalette(
                background: Color(red: 0.94, green: 0.90, blue: 0.84),
                iconFill: Color(red: 0.96, green: 0.93, blue: 0.88),
                shadow: Color(red: 0.72, green: 0.66, blue: 0.58),
                highlight: Color.white.opacity(0.85)
            )
        case 3:
            return NeumorphicPalette(
                background: Color(red: 0.88, green: 0.91, blue: 0.95),
                iconFill: Color(red: 0.92, green: 0.94, blue: 0.97),
                shadow: Color(red: 0.62, green: 0.68, blue: 0.78),
                highlight: Color.white.opacity(0.92)
            )
        case 4:
            return NeumorphicPalette(
                background: Color(red: 0.18, green: 0.19, blue: 0.22),
                iconFill: Color(red: 0.26, green: 0.27, blue: 0.31),
                shadow: Color.black,
                highlight: Color.white.opacity(0.08)
            )
        default:
            // Soft off-white surface; icon defaults to the SAME color as the
            // background (pure emboss). The Digit overrides this with #FAFAFF.
            return NeumorphicPalette(
                background: Color(red: 0.95, green: 0.95, blue: 0.96),
                iconFill: Color(red: 0.95, green: 0.95, blue: 0.96),
                shadow: Color(red: 0.62, green: 0.64, blue: 0.71),
                highlight: Color.white
            )
        }
    }
}

// MARK: - Plain embossed icon

struct NeumorphicPlainIcon: View {
    let symbol: String
    let iconSize: Double
    let palette: NeumorphicPalette
    let shadowOffsetX: CGFloat
    let shadowOffsetY: CGFloat
    let shadowRadius: CGFloat
    let shadowOpacity: CGFloat
    var iconOpacity: CGFloat = 1
    let revealDelay: Double
    let motionResponse: Double
    let motionDamping: Double
    let revealToken: Int

    @State private var revealed = false
    @State private var depth: CGFloat = 0

    var body: some View {
        // Single drop shadow with independent X / Y offset.
        Image(systemName: symbol)
            .font(.system(size: iconSize, weight: .semibold))
            .foregroundStyle(palette.iconFill)
            .scaleEffect(0.42 + 0.58 * depth)
            .opacity(revealed ? Double(iconOpacity) : 0)
            .shadow(color: palette.shadow.opacity(Double(shadowOpacity)),
                    radius: shadowRadius * depth, x: shadowOffsetX * depth, y: shadowOffsetY * depth)
            .accessibilityLabel(symbol)
            .task(id: "\(revealToken)-\(symbol)") {
                revealed = false
                depth = 0
                if revealDelay > 0.01 {
                    try? await Task.sleep(for: .seconds(revealDelay))
                    guard !Task.isCancelled else { return }
                }
                withAnimation(.spring(response: motionResponse, dampingFraction: motionDamping)) {
                    revealed = true
                    depth = 1
                }
            }
    }
}

// MARK: - Reveal timing

func neumorphicPillsAnimation(response: Double, damping: Double, useEase: Bool) -> Animation {
    let r = max(0.1, response)
    if useEase {
        return .easeInOut(duration: r)
    }
    return .spring(response: r, dampingFraction: damping)
}

// MARK: - Neumorphic Pills (separate component)
//
// A single neumorphic pill. At rest it's pressed INTO the surface (inset
// bevel); tapping the card pops it OUT (raised) and back. No icon cycling —
// the interaction is the pill's in↔out depth. An optional preset morphs a
// "+" into "×" as it pops.

struct NeumorphicPillsView: View {
    var title: String = StudioItem.neumorphicPills.title
    var specs: NeumorphicPillsSpecs = NeumorphicPillsSpecs(
        ComponentSpecState(defaults: StudioItem.neumorphicPills.specDefaults),
        sheet: StudioItem.neumorphicPills.specSheet!
    )
    var chrome: Bool = true

    /// false = pressed in (rest), true = popped out.
    @State private var poppedOut = false

    var body: some View {
        if chrome {
            ShaderPageLayout(title: title, aspectRatio: 1.0) { cardBody }
        } else {
            cardBody
        }
    }

    @ViewBuilder
    private var cardBody: some View {
        let palette = NeumorphicPalette.tone(Int(specs.surfaceTone.rounded()))
        ZStack {
            palette.background

            NeumorphicPill(
                iconIn: PillIcons.inIcon,
                iconOut: PillIcons.outIcon,
                toggle: poppedOut,
                iconSize: specs.iconSize,
                palette: palette,
                poppedOut: poppedOut,
                shadowOffset: CGFloat(specs.shadowOffset),
                shadowRadius: CGFloat(specs.shadowRadius),
                pillShadowIn: specs.pillShadowIn,
                pillShadowOut: specs.pillShadowOut,
                iconShadowIn: specs.iconShadowIn,
                iconShadowOut: specs.iconShadowOut
            )
        }
        .contentShape(Rectangle())
        .animation(
            neumorphicPillsAnimation(
                response: specs.motionResponse,
                damping: specs.motionDamping,
                useEase: specs.motionEase
            ),
            value: poppedOut
        )
        .onTapGesture { poppedOut.toggle() }
    }
}

// MARK: - The pill (inset at rest, pops out on tap)

struct NeumorphicPill: View {
    let iconIn: String
    /// When set, the icon morphs `iconIn` → `iconOut` driven by `toggle`.
    var iconOut: String? = nil
    var toggle: Bool = false
    let iconSize: Double
    let palette: NeumorphicPalette
    let poppedOut: Bool
    let shadowOffset: CGFloat
    let shadowRadius: CGFloat
    /// Pill bevel + icon emboss shadow strengths, pressed-in vs popped-out.
    let pillShadowIn: Double
    let pillShadowOut: Double
    let iconShadowIn: Double
    let iconShadowOut: Double

    private var shape: Capsule { Capsule(style: .continuous) }
    private var bevelStrength: Double { poppedOut ? pillShadowOut : pillShadowIn }
    private var iconStrength: Double { poppedOut ? iconShadowOut : iconShadowIn }

    var body: some View {
        embossIcon
            .padding(.horizontal, iconSize * 0.95)
            .padding(.vertical, iconSize * 0.58)
            .background { pillSurface }
    }

    /// Icon (#D3D3DA) carved by a Figma-spec drop shadow:
    /// white, offset (1,1), blur 0, opacity = icon shadow strength.
    /// Morphs between two template assets when `iconOut` is provided.
    private var embossIcon: some View {
        Group {
            if let iconOut {
                MorphingSymbolIcon(
                    currentAsset: iconIn,
                    nextAsset: iconOut,
                    toggle: toggle,
                    size: iconSize,
                    blurRadius: iconSize * 1.1,
                    color: NeumorphicPalette.pillIconFill
                )
            } else {
                Image(iconIn)
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
                    .foregroundStyle(NeumorphicPalette.pillIconFill)
            }
        }
        .shadow(color: .white.opacity(iconStrength), radius: 0, x: 1, y: 1)
    }

    @ViewBuilder
    private var pillSurface: some View {
        if poppedOut {
            shape
                .fill(palette.background)
                .overlay { shape.strokeBorder(palette.highlight.opacity(0.6), lineWidth: 1) }
                .shadow(color: palette.shadow.opacity(bevelStrength),
                        radius: shadowRadius, x: shadowOffset, y: shadowOffset)
                .shadow(color: palette.highlight.opacity(0.9),
                        radius: shadowRadius * 0.8, x: -shadowOffset, y: -shadowOffset)
        } else {
            shape
                .fill(palette.background)
                .overlay { innerShadow(color: palette.shadow.opacity(bevelStrength), x: shadowOffset, y: shadowOffset) }
                .overlay { innerShadow(color: palette.highlight.opacity(0.85), x: -shadowOffset, y: -shadowOffset) }
                .overlay { shape.strokeBorder(palette.highlight.opacity(0.3), lineWidth: 1) }
        }
    }

    private func innerShadow(color: Color, x: CGFloat, y: CGFloat) -> some View {
        shape
            .stroke(color, lineWidth: shadowRadius * 1.4)
            .blur(radius: shadowRadius * 0.7)
            .offset(x: x, y: y)
            .mask { shape.fill(.black) }
    }
}

#Preview {
    ZStack {
        Aurora.canvas.ignoresSafeArea()
        NeumorphicDigitView()
    }
}

// Card-only: just the component, full-bleed, on its own background.
#Preview("Neumorphic Digit · card", traits: .sizeThatFitsLayout) {
    NeumorphicDigitView(chrome: false)
        .frame(width: 430, height: 430)
}

#Preview("Neumorphic Pills · card", traits: .sizeThatFitsLayout) {
    NeumorphicPillsView(chrome: false)
        .frame(width: 430, height: 430)
}
