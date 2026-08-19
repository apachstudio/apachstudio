import SwiftUI

// MARK: - Layout

private enum FlameInGlassMetrics {
    static let pillWidth: CGFloat = 104
    static let pillHeight: CGFloat = 332
    static let travelRangeY: CGFloat = 88
    static let travelRangeX: CGFloat = 5

    /// Slightly larger canvas so travel doesn't expose empty edges before clipping.
    static var flameCanvasSize: CGSize {
        CGSize(width: pillWidth * 1.08, height: pillHeight * 1.06)
    }
}

private enum FlamePalette {
    static let violet = Color(red: 0.56, green: 0.12, blue: 0.98)
    static let purple = Color(red: 0.62, green: 0.18, blue: 0.92)
    static let void = Color(red: 0.08, green: 0.03, blue: 0.07)
    static let brown = Color(red: 0.32, green: 0.10, blue: 0.06)
    static let amber = Color(red: 1.0, green: 0.52, blue: 0.08)
    static let gold = Color(red: 1.0, green: 0.68, blue: 0.14)
}

// MARK: - Canvas gradient flame (Flame in Glass uses this inside the pill)

private struct UnifiedFlameBody: View {
    let size: CGSize
    let time: TimeInterval

    private struct FlameGlob {
        let cx, cy, rw, rh: CGFloat
        let color: Color
        let opacity: Double
        let blur: CGFloat
        let sway: CGFloat
        let bob: CGFloat
        let freq: Double
        let phase: Double
    }

    private static let globs: [FlameGlob] = [
        FlameGlob(cx: 0.5, cy: 0.84, rw: 1.05, rh: 0.52, color: FlamePalette.amber,  opacity: 0.78, blur: 38, sway: 0.12, bob: 0.05,  freq: 0.9, phase: 0.0),
        FlameGlob(cx: 0.5, cy: 0.68, rw: 0.92, rh: 0.44, color: FlamePalette.gold,   opacity: 0.62, blur: 34, sway: 0.13, bob: 0.055, freq: 1.1, phase: 1.1),
        FlameGlob(cx: 0.5, cy: 0.54, rw: 0.88, rh: 0.38, color: FlamePalette.brown,  opacity: 0.52, blur: 32, sway: 0.13, bob: 0.055, freq: 1.25, phase: 2.3),
        FlameGlob(cx: 0.5, cy: 0.44, rw: 0.82, rh: 0.30, color: FlamePalette.void,   opacity: 0.58, blur: 28, sway: 0.12, bob: 0.05,  freq: 1.45, phase: 3.6),
        FlameGlob(cx: 0.5, cy: 0.28, rw: 0.96, rh: 0.36, color: FlamePalette.purple, opacity: 0.64, blur: 36, sway: 0.12, bob: 0.05,  freq: 1.7, phase: 0.7),
        FlameGlob(cx: 0.5, cy: 0.22, rw: 0.78, rh: 0.28, color: FlamePalette.violet, opacity: 0.55, blur: 30, sway: 0.15, bob: 0.06,  freq: 2.0, phase: 4.2),
        FlameGlob(cx: 0.5, cy: 0.14, rw: 0.46, rh: 0.20, color: FlamePalette.violet, opacity: 0.42, blur: 22, sway: 0.20, bob: 0.05,  freq: 2.6, phase: 1.9),
    ]

    var body: some View {
        Canvas { context, canvasSize in
            context.blendMode = .plusLighter

            let swayGain: CGFloat = 4.0
            let t = time * 3.0

            for g in Self.globs {
                let swayX = (sin(t * g.freq + g.phase) * g.sway
                    + sin(t * g.freq * 0.47 + g.phase * 1.7) * g.sway * 0.4) * swayGain
                let bobY = cos(t * g.freq * 0.8 + g.phase) * g.bob * swayGain
                let pulse = 1.0 + CGFloat(sin(t * g.freq * 0.9 + g.phase)) * 0.06

                glow(
                    in: &context,
                    center: CGPoint(
                        x: canvasSize.width * (g.cx + swayX),
                        y: canvasSize.height * (g.cy + bobY)
                    ),
                    radius: CGSize(
                        width: canvasSize.width * g.rw * pulse,
                        height: canvasSize.height * g.rh * (2.0 - pulse)
                    ),
                    color: g.color, opacity: g.opacity, blur: g.blur
                )
            }
        }
        .frame(width: size.width, height: size.height)
        .blur(radius: 5)
    }

    private func glow(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGSize,
        color: Color,
        opacity: Double,
        blur: CGFloat
    ) {
        var layer = context
        layer.opacity = opacity
        layer.addFilter(.blur(radius: blur))
        let rect = CGRect(
            x: center.x - radius.width * 0.5,
            y: center.y - radius.height * 0.5,
            width: radius.width,
            height: radius.height
        )
        layer.fill(Path(ellipseIn: rect), with: .color(color))
    }
}

private struct TravelingFlameStack: View {
    let time: TimeInterval
    let size: CGSize

    private var travelOffset: CGSize {
        CGSize(
            width: sin(time * 0.62 + 0.4) * FlameInGlassMetrics.travelRangeX,
            height: sin(time * 0.95) * FlameInGlassMetrics.travelRangeY
        )
    }

    var body: some View {
        UnifiedFlameBody(size: size, time: time)
            .offset(travelOffset)
    }
}

// MARK: - Flame in Glass stage
//
// The Glass Pill capsule (liquid glass + morphing icon) holds one of two
// fills inside it:
//   • .gradient    — the Canvas traveling flame gradient.
//   • .liquidBlobs — the SDF Liquid blobs, re-tinted with the flame palette.

struct FlameInGlassView: View {
    var title: String = StudioItem.flameInGlass.title
    var chrome: Bool = true
    var specs: FlameInGlassSpecs = FlameInGlassSpecs(
        ComponentSpecState(defaults: StudioItem.flameInGlass.specDefaults),
        sheet: StudioItem.flameInGlass.specSheet!
    )

    @State private var startTime = Date()

    private var isLiquid: Bool { specs.fill >= 0.5 }
    private let pillIconSize: CGFloat = 40

    private var pillSize: CGSize {
        CGSize(width: FlameInGlassMetrics.pillWidth, height: FlameInGlassMetrics.pillHeight)
    }

    private var glassSpecs: SampleGlassPillSpecs {
        SampleGlassPillSpecs(
            ComponentSpecState(defaults: StudioItem.sampleGlassPill.specDefaults),
            sheet: StudioItem.sampleGlassPill.specSheet!
        )
    }

    private var liquidSpecs: SDFLiquidSpecs {
        let state = ComponentSpecState(defaults: StudioItem.sdfLiquid.specDefaults)
        state.values["smoothness"] = specs.smoothness
        state.values["glowAmount"] = specs.glowAmount
        state.values["motionSpeed"] = specs.motionSpeed
        return SDFLiquidSpecs(state, sheet: StudioItem.sdfLiquid.specSheet!)
    }

    @ViewBuilder
    private var fillView: some View {
        if isLiquid {
            SDFLiquidView(specs: liquidSpecs, chrome: false, useFlamePalette: true, mergedFill: true)
                .frame(width: pillSize.width, height: pillSize.height)
                .clipShape(Capsule())
        } else {
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSince(startTime)
                TravelingFlameStack(time: time, size: FlameInGlassMetrics.flameCanvasSize)
                    .frame(width: pillSize.width, height: pillSize.height)
                    .clipShape(Capsule())
            }
        }
    }

    private var pill: some View {
        ZStack {
            Color.black

            ZStack {
                fillView

                GlassPillView(
                    specs: glassSpecs,
                    pillSize: pillSize,
                    showBackground: false,
                    iconSize: pillIconSize,
                    iconA: PillIcons.inIcon,
                    iconB: PillIcons.outIcon,
                    iconKind: .asset,
                    iconColor: .white.opacity(0.6)
                )
            }
            .frame(width: pillSize.width, height: pillSize.height)
            .clipShape(Capsule())
        }
    }

    var body: some View {
        if chrome {
            ShaderPageLayout(title: title, aspectRatio: 1 / Cloud.bubbleAspect) { pill }
        } else {
            pill
        }
    }
}

// MARK: - SDF Flame (standalone component)
//
// Signed-distance-field flame (Matthew's note): stacked metaballs wobbling
// with value noise, smooth-unioned into one morphing body and colored
// warm→violet in the `flameSDF` Metal shader — GPU-only, no blurred shapes.
// This is its own component, rendered full-card (not inside a pill).

struct SDFFlame: View {
    let size: CGSize
    let time: TimeInterval
    var height: Double = 1
    var width: Double = 1
    var flicker: Double = 1
    var speed: Double = 1
    var softness: Double = 0.13
    var glow: Double = 0.55

    var body: some View {
        Color.black
            .frame(width: size.width, height: size.height)
            .colorEffect(
                ShaderLibrary.flameSDF(
                    .float2(Float(size.width), Float(size.height)),
                    .float(Float(time)),
                    .float(Float(height)),
                    .float(Float(width)),
                    .float(Float(flicker)),
                    .float(Float(speed)),
                    .float(Float(softness)),
                    .float(Float(glow))
                )
            )
    }
}

struct FlameView: View {
    var title: String = StudioItem.flame.title
    var chrome: Bool = true
    var specs: FlameSpecs = FlameSpecs(
        ComponentSpecState(defaults: StudioItem.flame.specDefaults),
        sheet: StudioItem.flame.specSheet!
    )

    @State private var startTime = Date()

    @ViewBuilder
    private var cardBody: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSince(startTime)
                SDFFlame(
                    size: geo.size,
                    time: time,
                    height: specs.height,
                    width: specs.width,
                    flicker: specs.flicker,
                    speed: specs.speed,
                    softness: specs.softness,
                    glow: specs.glow
                )
            }
        }
    }

    var body: some View {
        if chrome {
            ShaderPageLayout(title: title, aspectRatio: 0.72) { cardBody }
        } else {
            cardBody
        }
    }
}

// MARK: - Previews

private struct FlameInGlassPreview: View {
    let fill: Double

    var body: some View {
        FlameInGlassView(chrome: false, specs: specs)
            .frame(width: 300, height: 380)
    }

    private var specs: FlameInGlassSpecs {
        let state = ComponentSpecState(defaults: StudioItem.flameInGlass.specDefaults)
        state.values["fill"] = fill
        return FlameInGlassSpecs(state, sheet: StudioItem.flameInGlass.specSheet!)
    }
}

#Preview("Flame in Glass · gradient", traits: .sizeThatFitsLayout) {
    FlameInGlassPreview(fill: 0)
}

#Preview("Flame in Glass · liquid blobs", traits: .sizeThatFitsLayout) {
    FlameInGlassPreview(fill: 1)
}

#Preview("Flame · card", traits: .sizeThatFitsLayout) {
    FlameView(chrome: false)
        .frame(width: 300, height: 420)
}
