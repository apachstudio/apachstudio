import SwiftUI

// MARK: - SDF Liquid (Victor Baro final demo)
//
// Draggable light blobs from "SDF in Metal: Adding the Liquid to the Glass".
// Four glowing orbs float with lava-lamp motion, merge via smoothUnion when
// close, and follow the finger — the gooey liquid-glass glue from iOS 26.

private struct LiquidBlob {
    var center: CGPoint
    let restCenter: CGPoint
    var velocity: CGPoint = .zero
    let radius: CGFloat
    let colorIndex: Float
    let driftPhase: Double
    let driftSpeed: Double
}

struct SDFLiquidView: View {
    var title: String = StudioItem.sdfLiquid.title
    var specs: SDFLiquidSpecs = SDFLiquidSpecs(
        ComponentSpecState(defaults: StudioItem.sdfLiquid.specDefaults),
        sheet: StudioItem.sdfLiquid.specSheet!
    )
    var chrome: Bool = true
    /// Swaps the blob palette to the warm→violet flame colors (used by the
    /// Flame in Glass "liquid blobs" option).
    var useFlamePalette: Bool = false
    /// Big, overlapping, unclamped blobs that fuse into ONE gradient mass
    /// filling the frame — instead of separate floating orbs.
    var mergedFill: Bool = false

  @State private var blobs: [LiquidBlob] = SDFLiquidView.defaultBlobs
  @State private var draggedIndex: Int? = nil
  @State private var lastPhysicsTick: Date? = nil

    var body: some View {
        if chrome {
            ShaderPageLayout(title: title, aspectRatio: 1.0) {
                cardBody
            }
        } else {
            cardBody
        }
    }

    @ViewBuilder
    private var cardBody: some View {
        GeometryReader { geo in
            let size = geo.size

            TimelineView(.animation) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                let animatedBlobs = displayBlobs(at: time)
                let b0 = blobUniform(animatedBlobs[0])
                let b1 = blobUniform(animatedBlobs[1])
                let b2 = blobUniform(animatedBlobs[2])
                let b3 = blobUniform(animatedBlobs[3])

                Color.black
                    .colorEffect(
                        ShaderLibrary.sdfLiquidBlobs(
                            .float2(Float(size.width), Float(size.height)),
                            .float4(b0.0, b0.1, b0.2, b0.3),
                            .float4(b1.0, b1.1, b1.2, b1.3),
                            .float4(b2.0, b2.1, b2.2, b2.3),
                            .float4(b3.0, b3.1, b3.2, b3.3),
                            .float(Float(specs.smoothness)),
                            .float(Float(time)),
                            .float(Float(specs.glowAmount)),
                            .float(useFlamePalette ? 1 : 0)
                        )
                    )
                    .contentShape(Rectangle())
                    .gesture(dragGesture(in: size))
                    .onChange(of: context.date) { _, newDate in
                        guard draggedIndex == nil else { return }
                        stepIdleMotion(at: newDate, size: size)
                    }
                    .onAppear {
                        if mergedFill { blobs = Self.mergedBlobs }
                    }
            }
        }
    }

    private func displayBlobs(at time: Double) -> [LiquidBlob] {
        blobs.enumerated().map { index, blob in
            guard draggedIndex != index else { return blob }

            let drift = specs.motionSpeed
            let ox = sin(time * blob.driftSpeed + blob.driftPhase) * drift * 0.55
            let oy = cos(time * blob.driftSpeed * 1.17 + blob.driftPhase * 1.3) * drift * 0.48
            let floated = CGPoint(
                x: blob.center.x + ox,
                y: blob.center.y + oy
            )
            return LiquidBlob(
                center: clampedCenter(floated, radius: blob.radius),
                restCenter: blob.restCenter,
                velocity: blob.velocity,
                radius: blob.radius,
                colorIndex: blob.colorIndex,
                driftPhase: blob.driftPhase,
                driftSpeed: blob.driftSpeed
            )
        }
    }

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let point = normalizedPoint(value.location, in: size)
                if draggedIndex == nil {
                    draggedIndex = nearestBlobIndex(to: point)
                }
                guard let index = draggedIndex else { return }
                blobs[index].center = clampedCenter(point, radius: blobs[index].radius)
                blobs[index].velocity = .zero
            }
            .onEnded { value in
                guard let index = draggedIndex else { return }
                let point = normalizedPoint(value.location, in: size)
                blobs[index].center = clampedCenter(point, radius: blobs[index].radius)
                blobs[index].velocity = releaseVelocity(from: value.velocity, size: size)
                draggedIndex = nil
                lastPhysicsTick = nil
            }
    }

    private func stepIdleMotion(at date: Date, size: CGSize) {
        if lastPhysicsTick == nil {
            lastPhysicsTick = date
            return
        }
        guard let last = lastPhysicsTick else { return }
        let dt = min(date.timeIntervalSince(last), 1.0 / 30.0)
        guard dt > 1e-5 else { return }
        lastPhysicsTick = date

        let spring = specs.springStrength
        let damping = specs.damping

        for index in blobs.indices {
            var blob = blobs[index]
            let toRest = CGPoint(
                x: blob.restCenter.x - blob.center.x,
                y: blob.restCenter.y - blob.center.y
            )
            blob.velocity.x += toRest.x * spring * dt
            blob.velocity.y += toRest.y * spring * dt
            blob.velocity.x *= pow(damping, dt * 60)
            blob.velocity.y *= pow(damping, dt * 60)

            blob.center.x += blob.velocity.x * dt
            blob.center.y += blob.velocity.y * dt
            blob.center = clampedCenter(blob.center, radius: blob.radius)
            blobs[index] = blob
        }
    }

    private func nearestBlobIndex(to point: CGPoint) -> Int {
        var best = 0
        var bestDist = CGFloat.greatestFiniteMagnitude
        for (index, blob) in blobs.enumerated() {
            let dx = point.x - blob.center.x
            let dy = point.y - blob.center.y
            let dist = hypot(dx, dy)
            if dist < bestDist {
                bestDist = dist
                best = index
            }
        }
        return best
    }

    private func normalizedPoint(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: point.x / max(size.width, 1),
            y: point.y / max(size.height, 1)
        )
    }

    private func clampedCenter(_ center: CGPoint, radius: CGFloat) -> CGPoint {
        // Merged fill uses oversized blobs that intentionally bleed past the
        // edges (clipped by the pill), so don't clamp them inward.
        guard !mergedFill else { return center }
        let margin = radius + 0.04
        return CGPoint(
            x: min(max(center.x, margin), 1 - margin),
            y: min(max(center.y, margin), 1 - margin)
        )
    }

    private func releaseVelocity(from velocity: CGSize, size: CGSize) -> CGPoint {
        CGPoint(
            x: velocity.width / max(size.width, 1),
            y: velocity.height / max(size.height, 1)
        )
    }

    private func blobUniform(_ blob: LiquidBlob) -> (Float, Float, Float, Float) {
        (
            Float(blob.center.x - 0.5),
            Float(blob.center.y - 0.5),
            Float(blob.radius),
            blob.colorIndex
        )
    }

    /// Oversized overlapping blobs stacked down the frame — with high Merge
    /// they fuse into a single gradient mass (orange→violet) that fills the
    /// pill instead of reading as separate orbs.
    private static let mergedBlobs: [LiquidBlob] = [
        LiquidBlob(
            center: CGPoint(x: 0.50, y: 0.18), restCenter: CGPoint(x: 0.50, y: 0.18),
            radius: 0.64, colorIndex: 0.0, driftPhase: 0.3, driftSpeed: 0.42
        ),
        LiquidBlob(
            center: CGPoint(x: 0.40, y: 0.42), restCenter: CGPoint(x: 0.40, y: 0.42),
            radius: 0.62, colorIndex: 1.1, driftPhase: 1.5, driftSpeed: 0.52
        ),
        LiquidBlob(
            center: CGPoint(x: 0.60, y: 0.58), restCenter: CGPoint(x: 0.60, y: 0.58),
            radius: 0.62, colorIndex: 2.0, driftPhase: 2.7, driftSpeed: 0.48
        ),
        LiquidBlob(
            center: CGPoint(x: 0.50, y: 0.82), restCenter: CGPoint(x: 0.50, y: 0.82),
            radius: 0.64, colorIndex: 2.9, driftPhase: 3.6, driftSpeed: 0.45
        ),
    ]

    private static let defaultBlobs: [LiquidBlob] = [
        LiquidBlob(
            center: CGPoint(x: 0.34, y: 0.42),
            restCenter: CGPoint(x: 0.34, y: 0.42),
            radius: 0.13,
            colorIndex: 0,
            driftPhase: 0.2,
            driftSpeed: 0.72
        ),
        LiquidBlob(
            center: CGPoint(x: 0.62, y: 0.38),
            restCenter: CGPoint(x: 0.62, y: 0.38),
            radius: 0.11,
            colorIndex: 1.2,
            driftPhase: 1.4,
            driftSpeed: 0.88
        ),
        LiquidBlob(
            center: CGPoint(x: 0.48, y: 0.62),
            restCenter: CGPoint(x: 0.48, y: 0.62),
            radius: 0.095,
            colorIndex: 2.1,
            driftPhase: 2.6,
            driftSpeed: 0.65
        ),
        LiquidBlob(
            center: CGPoint(x: 0.52, y: 0.28),
            restCenter: CGPoint(x: 0.52, y: 0.28),
            radius: 0.085,
            colorIndex: 2.8,
            driftPhase: 3.8,
            driftSpeed: 0.95
        ),
    ]
}

#Preview {
    ZStack {
        Aurora.canvas.ignoresSafeArea()
        SDFLiquidView()
    }
}

#Preview("SDF Liquid · card", traits: .sizeThatFitsLayout) {
    SDFLiquidView(chrome: false)
        .frame(width: 430, height: 430)
}
