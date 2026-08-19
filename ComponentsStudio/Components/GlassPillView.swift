import SwiftUI

enum GlassPillIcons {
    /// Empty shopping bag outline.
    static let emptyBag = "bag"
    /// Wrapped gift — dramatic morph from the empty bag silhouette.
    static let bagWithGifts = "gift.fill"
}

enum GlassPillIconKind {
    case symbol
    case asset
}

/// Liquid Glass capsule with a morphing SF Symbol. Tap toggles between two icons.
struct GlassPillView: View {
    let specs: SampleGlassPillSpecs
    /// When set, the glass capsule fills this fixed size instead of hugging
    /// its icon — used to render the pill at the tall Flame-in-Glass size.
    var pillSize: CGSize? = nil
    /// When false, the opaque black backdrop is dropped so whatever sits
    /// behind the pill (e.g. the Flame gradient) shows through the glass.
    var showBackground: Bool = true
    /// Point size of the morphing SF Symbol.
    var iconSize: CGFloat = 22
    /// The two morphing icons (defaults to the shopping bag ↔ gift).
    var iconA: String = GlassPillIcons.emptyBag
    var iconB: String = GlassPillIcons.bagWithGifts
    var iconKind: GlassPillIconKind = .symbol
    var iconColor: Color = .white

    @State private var toggle = false
    @State private var current: String
    @State private var next: String?

    init(
        specs: SampleGlassPillSpecs,
        pillSize: CGSize? = nil,
        showBackground: Bool = true,
        iconSize: CGFloat = 22,
        iconA: String = GlassPillIcons.emptyBag,
        iconB: String = GlassPillIcons.bagWithGifts,
        iconKind: GlassPillIconKind = .symbol,
        iconColor: Color = .white
    ) {
        self.specs = specs
        self.pillSize = pillSize
        self.showBackground = showBackground
        self.iconSize = iconSize
        self.iconA = iconA
        self.iconB = iconB
        self.iconKind = iconKind
        self.iconColor = iconColor
        _current = State(initialValue: iconA)
    }

    var body: some View {
        ZStack {
            if showBackground {
                Color.black.ignoresSafeArea()
            }

            SampleGlassPill(
                specs: specs,
                currentSymbol: current,
                nextSymbol: next,
                toggle: toggle,
                pillSize: pillSize,
                iconSize: iconSize,
                iconKind: iconKind,
                iconColor: iconColor
            ) {
                morphToAlternateIcon()
            }
        }
        .environment(\.colorScheme, .dark)
    }

    private func morphToAlternateIcon() {
        // Base the destination on what's CURRENTLY shown (toggle ? next :
        // current), so every tap reliably swaps to the other icon and back —
        // otherwise alternate taps would land on the same symbol.
        let displayed = toggle ? (next ?? current) : current
        let destination = displayed == iconA ? iconB : iconA
        withAnimation(.interpolatingSpring(duration: 0.7)) {
            if toggle {
                current = destination
            } else {
                next = destination
            }
            toggle.toggle()
        }
    }
}

struct SampleGlassPill: View {
    var specs: SampleGlassPillSpecs
    var currentSymbol: String = GlassPillIcons.emptyBag
    var nextSymbol: String?
    var toggle: Bool = false
    /// When set, the glass capsule fills this fixed size (icon centered)
    /// instead of hugging its content + padding.
    var pillSize: CGSize? = nil
    /// Point size of the morphing icon.
    var iconSize: CGFloat = 22
    var iconKind: GlassPillIconKind = .symbol
    var iconColor: Color = .white
    var onTap: (() -> Void)?

    @State private var isPopping = false

    var body: some View {
        Button {
            triggerPop()
            onTap?()
        } label: {
            morphingIcon
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)
            .frame(width: pillSize?.width, height: pillSize?.height)
            .background {
                Capsule()
                    .fill(.clear)
                    .glassEffect(
                        specs.tintOpacity > 0.01
                            ? .regular.interactive().tint(.white.opacity(specs.tintOpacity))
                            : .regular.interactive(),
                        in: Capsule()
                    )
                    .opacity(specs.glassOpacity)
            }
            .scaleEffect(displayScale)
            // Whole capsule is the tap target — tapping anywhere morphs the icon.
            .contentShape(Capsule())
        }
        .buttonStyle(GlassPillPressStyle(pressScale: specs.pressScale))
        .accessibilityLabel(accessibilityTitle)
        .accessibilityHint("Toggles the bag icon with a morphing animation")
    }

    private var displayScale: CGFloat {
        let base = specs.restScale
        return isPopping ? base * (1.0 + specs.pressPop) : base
    }

    @ViewBuilder
    private var morphingIcon: some View {
        switch iconKind {
        case .symbol:
            MorphingSymbolIcon(
                current: currentSymbol,
                next: nextSymbol,
                toggle: toggle,
                size: iconSize,
                blurRadius: 28,
                color: iconColor
            )
        case .asset:
            MorphingSymbolIcon(
                currentAsset: currentSymbol,
                nextAsset: nextSymbol,
                toggle: toggle,
                size: iconSize,
                blurRadius: 28,
                color: iconColor
            )
        }
    }

    private var accessibilityTitle: String {
        switch iconKind {
        case .symbol:
            currentSymbol == GlassPillIcons.emptyBag
                ? "Empty shopping bag"
                : "Shopping bag with gifts"
        case .asset:
            toggle ? "Pill icon out" : "Pill icon in"
        }
    }

    private func triggerPop() {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.52)) {
            isPopping = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(.spring(response: 0.36, dampingFraction: 0.72)) {
                isPopping = false
            }
        }
    }
}

struct GlassPillPressStyle: ButtonStyle {
    let pressScale: Double

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressScale : 1.0)
            .animation(.spring(response: 0.26, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

#Preview("Glass Pill") {
    GlassPillView(
        specs: SampleGlassPillSpecs(
            ComponentSpecState(defaults: StudioItem.sampleGlassPill.specDefaults),
            sheet: StudioItem.sampleGlassPill.specSheet!
        )
    )
}
