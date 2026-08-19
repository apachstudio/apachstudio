import SwiftUI

// MARK: - Refractive Photo (Victor Baro tutorial reproduction)
//
// Faithful reproduction of Victor Baro's "Implementing a Refractive Glass
// Shader in Metal" article: a circular glass lens sits over a background image
// and refracts what's behind it, with a center-focused `1 - pow(r, falloff)`
// magnification curve, chromatic aberration toward the edge, a cool rim
// highlight biased to an upper-left light, and a soft directional drop shadow /
// occlusion.
//
// As the tutorial does, the `refractiveGlass` Metal shader is applied to the
// WHOLE content via `.layerEffect` — the "glass" is just the region the shader
// distorts around `glassCenter`. The lens idles on a slow Lissajous drift,
// can be dragged with elastic settle on release, and the swirl inside the
// bubble responds to motion. The background is a bundled local image.

struct RefractiveGlassView: View {
    private static let specSheet = ComponentSpecSheet(
        categories: [
            ComponentSpecCategory(
                id: "lens",
                label: "Lens",
                controls: [
                    .init(id: "refraction", label: "Refract", kind: .slider(0.0...0.6, format: "%.2f")),
                    .init(id: "falloff", label: "Falloff", kind: .slider(1.0...16.0, format: "%.1f")),
                    .init(id: "swirl", label: "Swirl", kind: .slider(0.0...6.28, format: "%.2f")),
                    .init(id: "glassRadius", label: "Radius", kind: .slider(60...260, format: "%.0f")),
                    .init(id: "chromatic", label: "Chroma", kind: .slider(0.0...0.4, format: "%.2f")),
                ]
            ),
        ],
        defaults: [
            "refraction": 0.36, "falloff": 15.4, "swirl": 0.86, "glassRadius": 86, "chromatic": 0.00,
        ]
    )

    var title: String = "Refractive Photo"
    var specs: RefractiveGlassSpecs = RefractiveGlassSpecs(
        ComponentSpecState(defaults: Self.specSheet.defaults),
        sheet: Self.specSheet
    )

    /// Rest anchor for idle float (normalized [0,1]); springs here after drag.
    @State private var restCenter = CGPoint(x: 0.5, y: 0.42)
    @State private var dragCenter: CGPoint? = nil
    @State private var isDragging = false
    @State private var lensVelocity = CGPoint.zero
    @State private var previousSample: (center: CGPoint, time: Date)? = nil

    var body: some View {
        ShaderPageLayout(title: title, aspectRatio: 0.78) {
            GeometryReader { geo in
                RefractiveGlassLensCard(
                    size: geo.size,
                    specs: specs,
                    restCenter: $restCenter,
                    dragCenter: $dragCenter,
                    isDragging: $isDragging,
                    lensVelocity: $lensVelocity,
                    previousSample: $previousSample
                )
            }
        }
    }
}

// MARK: - Animated lens card

private struct RefractiveGlassLensCard: View {
    let size: CGSize
    let specs: RefractiveGlassSpecs

    @Binding var restCenter: CGPoint
    @Binding var dragCenter: CGPoint?
    @Binding var isDragging: Bool
    @Binding var lensVelocity: CGPoint
    @Binding var previousSample: (center: CGPoint, time: Date)?

    private let floatAmplitude: CGFloat = 0.055
    private let floatPeriodX: Double = 8.2
    private let floatPeriodY: Double = 5.6
    private let settleSpring = Animation.interpolatingSpring(stiffness: 260, damping: 17)

    var body: some View {
        TimelineView(.animation) { context in
            RefractiveGlassLensFrame(
                date: context.date,
                size: size,
                specs: specs,
                restCenter: restCenter,
                dragCenter: dragCenter,
                isDragging: isDragging,
                lensVelocity: lensVelocity,
                onDragChanged: handleDragChanged,
                onDragEnded: handleDragEnded
            )
        }
    }

    private func handleDragChanged(location: CGPoint, time: Date) {
        let center = clampedCenter(location)
        if !isDragging {
            isDragging = true
            previousSample = nil
        }
        trackVelocity(center: center, at: time)
        dragCenter = center
    }

    private func handleDragEnded(location: CGPoint, velocity: CGSize) {
        let target = clampedCenter(location)
        isDragging = false
        dragCenter = nil
        previousSample = nil
        withAnimation(settleSpring) {
            restCenter = target
        }
        lensVelocity = CGPoint(
            x: velocity.width / max(size.width, 1),
            y: velocity.height / max(size.height, 1)
        )
    }

    private func trackVelocity(center: CGPoint, at time: Date) {
        if let prev = previousSample {
            let dt = time.timeIntervalSince(prev.time)
            if dt > 1e-4 {
                lensVelocity = CGPoint(
                    x: (center.x - prev.center.x) / dt,
                    y: (center.y - prev.center.y) / dt
                )
            }
        }
        previousSample = (center, time)
    }

    private func clampedCenter(_ center: CGPoint) -> CGPoint {
        let marginX = specs.glassRadius / max(size.width, 1)
        let marginY = specs.glassRadius / max(size.height, 1)
        return CGPoint(
            x: min(max(center.x, marginX), 1 - marginX),
            y: min(max(center.y, marginY), 1 - marginY)
        )
    }

    private func idleFloatOffset(at t: Double) -> CGPoint {
        let wx = 2 * Double.pi / floatPeriodX
        let wy = 2 * Double.pi / floatPeriodY * 1.28
        let x = floatAmplitude * CGFloat(sin(t * wx))
        let y = floatAmplitude * 0.88 * CGFloat(sin(t * wy + 0.65))
        return CGPoint(x: x, y: y)
    }

    private func idleFloatVelocity(at t: Double) -> CGPoint {
        let wx = 2 * Double.pi / floatPeriodX
        let wy = 2 * Double.pi / floatPeriodY * 1.28
        let vx = floatAmplitude * wx * CGFloat(cos(t * wx))
        let vy = floatAmplitude * 0.88 * wy * CGFloat(cos(t * wy + 0.65))
        return CGPoint(x: vx, y: vy)
    }
}

private struct RefractiveGlassLensFrame: View {
    let date: Date
    let size: CGSize
    let specs: RefractiveGlassSpecs
    let restCenter: CGPoint
    let dragCenter: CGPoint?
    let isDragging: Bool
    let lensVelocity: CGPoint
    let onDragChanged: (CGPoint, Date) -> Void
    let onDragEnded: (CGPoint, CGSize) -> Void

    private let cardShape = RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
    private let floatAmplitude: CGFloat = 0.055
    private let floatPeriodX: Double = 8.2
    private let floatPeriodY: Double = 5.6
    private let idleSwirlSpeed: Double = 0.55

    var body: some View {
        let t = date.timeIntervalSinceReferenceDate
        let floatOffset = isDragging ? CGPoint.zero : idleFloatOffset(at: t)
        let idleCenter = clampedCenter(
            CGPoint(x: restCenter.x + floatOffset.x, y: restCenter.y + floatOffset.y)
        )
        let displayCenter = isDragging ? (dragCenter ?? idleCenter) : idleCenter
        let swirlPhase = Float(t * idleSwirlSpeed)
        let shaderVelocity = isDragging ? lensVelocity : idleFloatVelocity(at: t)

        portraitContent
            .drawingGroup()
            .layerEffect(
                ShaderLibrary.refractiveGlass(
                    .float2(Float(size.width), Float(size.height)),
                    .float2(Float(displayCenter.x), Float(displayCenter.y)),
                    .float(Float(specs.glassRadius)),
                    .float(Float(specs.refraction)),
                    .float(Float(max(specs.falloff, 0.01))),
                    .float(Float(specs.swirl)),
                    .float(0),
                    .float(Float(specs.chromatic)),
                    .float(0),
                    .float(0),
                    .float(0),
                    .float(0),
                    .float(swirlPhase),
                    .float2(Float(shaderVelocity.x), Float(shaderVelocity.y))
                ),
                maxSampleOffset: CGSize(width: 240, height: 240)
            )
            .clipShape(cardShape)
            .contentShape(cardShape)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        onDragChanged(
                            CGPoint(
                                x: value.location.x / max(size.width, 1),
                                y: value.location.y / max(size.height, 1)
                            ),
                            Date()
                        )
                    }
                    .onEnded { value in
                        onDragEnded(
                            CGPoint(
                                x: value.location.x / max(size.width, 1),
                                y: value.location.y / max(size.height, 1)
                            ),
                            value.velocity
                        )
                    }
            )
    }

    private var portraitContent: some View {
        Image("RefractiveGlassBG")
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)
            .clipped()
    }

    private func idleFloatOffset(at t: Double) -> CGPoint {
        let wx = 2 * Double.pi / floatPeriodX
        let wy = 2 * Double.pi / floatPeriodY * 1.28
        let x = floatAmplitude * CGFloat(sin(t * wx))
        let y = floatAmplitude * 0.88 * CGFloat(sin(t * wy + 0.65))
        return CGPoint(x: x, y: y)
    }

    private func idleFloatVelocity(at t: Double) -> CGPoint {
        let wx = 2 * Double.pi / floatPeriodX
        let wy = 2 * Double.pi / floatPeriodY * 1.28
        let vx = floatAmplitude * wx * CGFloat(cos(t * wx))
        let vy = floatAmplitude * 0.88 * wy * CGFloat(cos(t * wy + 0.65))
        return CGPoint(x: vx, y: vy)
    }

    private func clampedCenter(_ center: CGPoint) -> CGPoint {
        let marginX = specs.glassRadius / max(size.width, 1)
        let marginY = specs.glassRadius / max(size.height, 1)
        return CGPoint(
            x: min(max(center.x, marginX), 1 - marginX),
            y: min(max(center.y, marginY), 1 - marginY)
        )
    }
}

#Preview {
    ZStack {
        Aurora.canvas.ignoresSafeArea()
        RefractiveGlassView()
    }
}
