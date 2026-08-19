import SwiftUI

// MARK: - Morphing transition (MorphingDemo)
//
// Tutorial steps mirrored from https://github.com/yangliu-1995/MorphingDemo:
// 1. Add the `alphaThreshold` Metal stitchable (StudioShaders.metal).
// 2. Blur the icon layer while a spring drives `progress` 0 → 1.
// 3. Apply `.layerEffect(ShaderLibrary.alphaThreshold())` to threshold alpha.
// 4. Swap the underlying icon at the midpoint of the animation.

enum MorphingIconSource: Equatable {
    case symbol(String)
    case asset(String)
}

@Animatable
struct MorphingModifier: ViewModifier {
    var blurRadius: CGFloat
    var progress: CGFloat

    func body(content: Content) -> some View {
        content
            .compositingGroup()
            .blur(radius: blurRadius * blurProgress)
            .visualEffect { content, proxy in
                content.layerEffect(ShaderLibrary.alphaThreshold(), maxSampleOffset: proxy.size)
            }
    }

    private var blurProgress: CGFloat {
        progress > 0.5 ? abs(1 - progress) : progress
    }
}

extension View {
    /// Blur + `alphaThreshold` morph used by Glass Pill.
    func morphingTransition(blurRadius: CGFloat, progress: CGFloat) -> some View {
        modifier(MorphingModifier(blurRadius: blurRadius, progress: progress))
    }

    /// Mercury melt morph used by Talk Pill — directional stretch, filaments,
    /// chromatic split, specular rim. Chaos peaks at progress 0.5.
    func liquidMorphingTransition(
        progress: CGFloat,
        blurRadius: CGFloat,
        intensity: CGFloat = 1.15,
        chroma: CGFloat = 1.0
    ) -> some View {
        modifier(
            LiquidMorphModifier(
                progress: progress,
                blurRadius: blurRadius,
                intensity: intensity,
                chroma: chroma
            )
        )
    }
}

@Animatable
private struct LiquidMorphModifier: ViewModifier {
    var progress: CGFloat
    var blurRadius: CGFloat
    var intensity: CGFloat
    var chroma: CGFloat

    func body(content: Content) -> some View {
        let bloom: CGFloat = 36
        content
            .compositingGroup()
            .padding(bloom)
            .blur(radius: blurRadius * melt)
            .visualEffect { content, proxy in
                content.layerEffect(
                    ShaderLibrary.liquidMorph(
                        .float2(proxy.size),
                        .float(Float(progress)),
                        .float(Float(intensity)),
                        .float(Float(chroma))
                    ),
                    maxSampleOffset: proxy.size
                )
            }
            .padding(-bloom)
            .scaleEffect(1 + melt * 0.42)
    }

    private var melt: CGFloat {
        CGFloat(pow(sin(Double(progress) * .pi), 0.52))
    }
}

/// Two icons (SF Symbols or asset catalog templates) that morph into each other when `toggle` flips.
struct MorphingSymbolIcon: View {
    let current: MorphingIconSource
    let next: MorphingIconSource?
    let toggle: Bool
    var size: CGFloat = 22
    var blurRadius: CGFloat = 28
    var color: Color = .white

    /// SF Symbol morph (existing API).
    init(
        current: String,
        next: String?,
        toggle: Bool,
        size: CGFloat = 22,
        blurRadius: CGFloat = 28,
        color: Color = .white
    ) {
        self.current = .symbol(current)
        self.next = next.map { .symbol($0) }
        self.toggle = toggle
        self.size = size
        self.blurRadius = blurRadius
        self.color = color
    }

    /// Asset catalog template morph.
    init(
        currentAsset: String,
        nextAsset: String?,
        toggle: Bool,
        size: CGFloat = 22,
        blurRadius: CGFloat = 28,
        color: Color = .white
    ) {
        self.current = .asset(currentAsset)
        self.next = nextAsset.map { .asset($0) }
        self.toggle = toggle
        self.size = size
        self.blurRadius = blurRadius
        self.color = color
    }

    var body: some View {
        ZStack {
            if toggle {
                iconView(next ?? current)
            } else {
                iconView(current)
            }
        }
        .foregroundStyle(color)
        .frame(width: size + 4, height: size + 4)
        .morphingTransition(blurRadius: blurRadius, progress: toggle ? 1 : 0)
    }

    @ViewBuilder
    private func iconView(_ source: MorphingIconSource) -> some View {
        switch source {
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: size, weight: .semibold))
        case .asset(let name):
            Image(name)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        }
    }
}

enum PillIcons {
    static let inIcon = "PillIconIn"
    static let outIcon = "PillIconOut"
}
