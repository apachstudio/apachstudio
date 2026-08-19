import SwiftUI

// MARK: - WWDC24 ripple modifier
//
// Builds the `photoRipple` Metal shader for one wave and applies it via
// `.layerEffect`, so the photo (and orange background) genuinely distort.

struct RippleModifier: ViewModifier {
    let origin: CGPoint
    let elapsedTime: TimeInterval
    let duration: TimeInterval

    var amplitude: Double
    var frequency: Double
    var decay: Double
    var speed: Double
    var highlight: Double

    func body(content: Content) -> some View {
        let shader = ShaderLibrary.photoRipple(
            .float2(origin),
            .float(Float(elapsedTime)),
            .float(Float(amplitude)),
            .float(Float(frequency)),
            .float(Float(decay)),
            .float(Float(speed)),
            .float(Float(highlight))
        )
        let maxOffset = CGSize(width: amplitude, height: amplitude)

        content.layerEffect(
            shader,
            maxSampleOffset: maxOffset,
            isEnabled: elapsedTime > 0 && elapsedTime < duration
        )
    }
}

/// Photo card whose portrait genuinely ripples when tapped — Apple WWDC24
/// displacement shader. Repeated taps spawn coexisting overlapping waves; each
/// is born under the touch, throws ~3 bright-white crests, and decays in ~1.5s.
struct PhotoRippleView: View {
    var title: String = StudioItem.photoRipple.title
    var imageURL: URL? = StudioSampleData.shaderPhotoURL
    var specs: PhotoRippleSpecs = PhotoRippleSpecs(
        ComponentSpecState(defaults: StudioItem.photoRipple.specDefaults),
        sheet: StudioItem.photoRipple.specSheet!
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

    private let maxRipples = 8

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
                        SpatialTapGesture()
                            .onEnded { value in spawn(at: value.location, now: now) }
                    )
            }
        }
    }

    /// Base portrait with every active ripple stacked on top as a layerEffect.
    /// Stacking re-samples the already-distorted layer, so overlapping waves
    /// interact like real water.
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
            let elapsed = now - ripple.start
            view = AnyView(
                view.modifier(
                    RippleModifier(
                        origin: ripple.origin,
                        elapsedTime: elapsed,
                        duration: specs.duration,
                        amplitude: specs.amplitude,
                        frequency: specs.frequency,
                        decay: specs.decay,
                        speed: specs.speed,
                        highlight: specs.highlight
                    )
                )
            )
        }

        return view
    }

    private func spawn(at location: CGPoint, now: TimeInterval) {
        let ripple = ActiveRipple(origin: location, start: now)
        ripples.append(ripple)
        if ripples.count > maxRipples {
            ripples.removeFirst(ripples.count - maxRipples)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + specs.duration + 0.1) {
            ripples.removeAll { $0.id == ripple.id }
        }
    }
}

#Preview {
    ZStack {
        Aurora.canvas.ignoresSafeArea()
        PhotoRippleView()
    }
}

// Card-only: just the component, full-bleed, on its own background.
#Preview("Liquid Photo · card", traits: .sizeThatFitsLayout) {
    PhotoRippleView(chrome: false)
        .frame(width: 430, height: 430)
}
