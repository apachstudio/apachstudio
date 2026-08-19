import SwiftUI

// MARK: - Photo Ripple — Liquid Glass fusion
//
// Premium fusion of Liquid Photo (WWDC24 expanding wave + crest displacement)
// and Refractive Photo (Baro normal-based refraction, chroma, specular rim).
// Uses the same photo card + ShaderPageLayout as Liquid Photo; interaction
// follows the finger via a throttled drag trail.
//
// Each ring is ONE traveling glass wavefront (`R = speed * age`). The unified
// `photoRipple2` shader is stacked on the photo via `.layerEffect` (like PR1),
// so overlapping ripples compound through re-sampling.

struct Ripple2Modifier: ViewModifier {
    let origin: CGPoint
    let age: TimeInterval

    var speed: Double
    var bandWidth: Double
    var refract: Double
    var glint: Double
    var falloff: Double
    var swirl: Double
    var displacement: Double
    var chromatic: Double
    var maxRadius: Double
    var life: Double
    var size: CGSize

    func body(content: Content) -> some View {
        let shader = ShaderLibrary.photoRipple2(
            .float2(origin),
            .float(Float(age)),
            .float(Float(speed)),
            .float(Float(bandWidth)),
            .float(Float(refract)),
            .float(Float(glint)),
            .float(Float(falloff)),
            .float(Float(swirl)),
            .float(Float(displacement)),
            .float(Float(chromatic)),
            .float(Float(maxRadius)),
            .float(Float(life)),
            .float2(size)
        )
        let maxOffset = bandWidth + refract + displacement + chromatic * 10 + abs(swirl) * 40

        content.layerEffect(
            shader,
            maxSampleOffset: CGSize(width: maxOffset, height: maxOffset),
            isEnabled: age < life + 0.1
        )
    }
}

struct PhotoRipple2View: View {
    var title: String = StudioItem.photoRipple2.title
    var imageURL: URL? = StudioSampleData.shaderPhotoURL
    var specs: PhotoRipple2Specs = PhotoRipple2Specs(
        ComponentSpecState(defaults: StudioItem.photoRipple2.specDefaults),
        sheet: StudioItem.photoRipple2.specSheet!
    )
    /// When false, renders only the card content (no page chrome) so an
    /// Xcode preview can show the component full-bleed — the card corner
    /// rounding also drops to 0 so the photo fills the whole frame.
    var chrome: Bool = true

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: chrome ? Theme.Radius.card : 0, style: .continuous)
    }

    private struct ActiveRipple: Identifiable {
        let id = UUID()
        var origin: CGPoint
        var start: TimeInterval
    }

    @State private var ripples: [ActiveRipple] = []
    @State private var lastEmitPoint: CGPoint?
    @State private var lastEmitTime: TimeInterval = 0

    private let maxRipples = 10
    private let emitInterval: TimeInterval = 0.07

    var body: some View {
        if chrome {
            ShaderPageLayout(title: title, aspectRatio: 1 / Cloud.bubbleAspect) { cardBody }
        } else {
            cardBody
        }
    }

    @ViewBuilder
    private var cardBody: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate

            GeometryReader { geo in
                let size = geo.size

                rippled(now: now, size: size)
                    .contentShape(cardShape)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in emit(at: value.location) }
                            .onEnded { _ in lastEmitPoint = nil }
                    )
            }
        }
    }

    /// Same stacking model as Liquid Photo — one RemoteImage, each active ring
    /// adds a `.layerEffect` so disturbances compound through re-sampling.
    private func rippled(now: TimeInterval, size: CGSize) -> some View {
        var view = AnyView(
            RemoteImage(url: imageURL)
                .frame(width: size.width, height: size.height)
                .clipShape(cardShape)
                .overlay(
                    cardShape.stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                )
        )

        for ripple in ripples {
            let age = now - ripple.start
            view = AnyView(
                view.modifier(
                    Ripple2Modifier(
                        origin: ripple.origin,
                        age: age,
                        speed: specs.speed,
                        bandWidth: specs.bandWidth,
                        refract: specs.refract,
                        glint: specs.glint,
                        falloff: specs.falloff,
                        swirl: specs.swirl,
                        displacement: specs.displacement,
                        chromatic: specs.chromatic,
                        maxRadius: specs.maxRadius,
                        life: specs.life,
                        size: size
                    )
                )
            )
        }

        return view
    }

    private func emit(at location: CGPoint) {
        let now = Date().timeIntervalSinceReferenceDate
        let movedEnough: Bool = {
            guard let last = lastEmitPoint else { return true }
            return hypot(location.x - last.x, location.y - last.y) >= specs.emitSpacing
        }()
        let timeEnough = (now - lastEmitTime) >= emitInterval

        guard lastEmitPoint == nil || movedEnough || timeEnough else { return }

        spawn(at: location, now: now)
        lastEmitPoint = location
        lastEmitTime = now
    }

    private func spawn(at location: CGPoint, now: TimeInterval) {
        let ripple = ActiveRipple(origin: location, start: now)
        ripples.append(ripple)
        if ripples.count > maxRipples {
            ripples.removeFirst(ripples.count - maxRipples)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + specs.life + 0.1) {
            ripples.removeAll { $0.id == ripple.id }
        }
    }
}

#Preview {
    ZStack {
        Aurora.canvas.ignoresSafeArea()
        PhotoRipple2View()
    }
}

// Card-only: just the component, full-bleed, on its own background.
#Preview("Photo Ripple · card", traits: .sizeThatFitsLayout) {
    PhotoRipple2View(chrome: false)
        .frame(width: 430, height: 430)
}
