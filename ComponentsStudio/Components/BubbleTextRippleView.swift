import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Refractive glass lens card (text or sphere content)
//
// Text mode — ping-pong lens refracts only the typography; the photo bg stays flat.
// Sphere mode — full-card lens with a fixed rest anchor + gentle idle drift (drag to move).

struct BubbleTextRippleView: View {
    enum CardContent: Hashable {
        case text
        case sphere
    }

    var title: String = StudioItem.bubbleTextRipple.title
    var content: CardContent = .sphere
    var specs: BubbleTextRippleSpecs = BubbleTextRippleSpecs(
        ComponentSpecState(defaults: StudioItem.bubbleTextRipple.specDefaults),
        sheet: StudioItem.bubbleTextRipple.specSheet!
    )
    /// When false, renders only the card content (no page chrome) so an
    /// Xcode preview can show the component full-bleed — the card corner
    /// rounding also drops to 0 so the content fills the whole frame.
    var chrome: Bool = true

    // Ping-pong state (text mode only)
    @State private var bubbleCenter = CGPoint(x: 0.38, y: 0.44)
    @State private var bubbleVelocity = CGPoint(x: 0.22, y: 0.17)
    @State private var isDragging = false
    @State private var dragCenter: CGPoint? = nil
    @State private var dragVelocity = CGPoint.zero
    @State private var previousSample: (center: CGPoint, time: Date)? = nil
    @State private var lastPhysicsTick: Date? = nil

    // Fixed-lens state (sphere mode)
    @State private var restCenter = CGPoint(x: 0.5, y: 0.44)
    @State private var sphereDragCenter: CGPoint? = nil
    @State private var sphereIsDragging = false
    @State private var lensVelocity = CGPoint.zero
    @State private var spherePreviousSample: (center: CGPoint, time: Date)? = nil

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: chrome ? Theme.Radius.card : 0, style: .continuous)
    }
    private let idleSwirlSpeed: Double = 0.55
    private let bounceRestitution: CGFloat = 0.965
    private let minPingPongSpeed: CGFloat = 0.14
    private let maxPingPongSpeed: CGFloat = 0.52
    private let velocityDamping: CGFloat = 0.9992

    // Soft contact shadow grounding the lens "bubble" over the photo in
    // text mode. The lens itself is just a refraction region (no drawn
    // surface), so a faint blurred disc, offset down-right, reads as the
    // bubble's drop shadow.
    private let bubbleShadowOpacity: Double = 0.16
    private let bubbleShadowBlur: CGFloat = 22
    private let bubbleShadowOffset: CGFloat = 10

    private static let apachLabel = "apach"
    private static let textHorizontalPadding: CGFloat = 12

    init(
        title: String = StudioItem.bubbleTextRipple.title,
        content: CardContent = .sphere,
        specs: BubbleTextRippleSpecs = BubbleTextRippleSpecs(
            ComponentSpecState(defaults: StudioItem.bubbleTextRipple.specDefaults),
            sheet: StudioItem.bubbleTextRipple.specSheet!
        ),
        chrome: Bool = true
    ) {
        self.title = title
        self.content = content
        self.specs = specs
        self.chrome = chrome
    }

    var body: some View {
        if chrome {
            ShaderPageLayout(title: title, aspectRatio: 0.78) { cardBody }
        } else {
            cardBody
        }
    }

    @ViewBuilder
    private var cardBody: some View {
        GeometryReader { geo in
            let size = geo.size

            Group {
                switch content {
                case .text:
                    textStage(size: size)
                case .sphere:
                    sphereStage(size: size)
                }
            }
            .clipShape(cardShape)
            .contentShape(cardShape)
        }
    }

    // MARK: - Text stage (ping-pong lens on typography only)

    private func textStage(size: CGSize) -> some View {
        TimelineView(.animation) { context in
            let now = context.date
            let time = now.timeIntervalSinceReferenceDate
            let displayCenter = isDragging ? (dragCenter ?? bubbleCenter) : bubbleCenter
            let shaderVelocity = isDragging ? dragVelocity : bubbleVelocity
            let swirlPhase = Float(time * idleSwirlSpeed)

            ZStack {
                Image("RefractiveTextBG")
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()

                // Drop shadow under the lens bubble (between photo + text).
                Circle()
                    .fill(Color.black)
                    .frame(width: CGFloat(specs.glassRadius) * 2,
                           height: CGFloat(specs.glassRadius) * 2)
                    .blur(radius: bubbleShadowBlur)
                    .opacity(bubbleShadowOpacity)
                    .position(
                        x: displayCenter.x * size.width + bubbleShadowOffset,
                        y: displayCenter.y * size.height + bubbleShadowOffset
                    )
                    .allowsHitTesting(false)

                refractiveTextLayer(
                    size: size,
                    time: time,
                    displayCenter: displayCenter,
                    shaderVelocity: shaderVelocity,
                    swirlPhase: swirlPhase
                )
            }
            .frame(width: size.width, height: size.height)
            .gesture(textDragGesture(in: size))
            .onChange(of: context.date) { _, newDate in
                guard !isDragging else { return }
                stepPhysics(at: newDate, size: size)
            }
        }
    }

    private func refractiveTextLayer(
        size: CGSize,
        time: TimeInterval,
        displayCenter: CGPoint,
        shaderVelocity: CGPoint,
        swirlPhase: Float
    ) -> some View {
        // Full bleed (full screen) gives the wordmark a wider 50pt side
        // margin; the chrome card keeps the tight 12pt fit.
        let sidePadding: CGFloat = chrome ? Self.textHorizontalPadding : 50
        let fontSize = Self.fittedDripdropSize(cardWidth: size.width, padding: sidePadding)
        let verticalOffset = Self.dripdropVerticalCenterOffset(fontSize: fontSize)
        let liquidTime = Float(time)

        return Text(Self.apachLabel)
            .font(AppFont.dripdrop(fontSize))
            .foregroundStyle(.black)
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .frame(width: size.width, height: size.height)
            .offset(y: verticalOffset)
            .drawingGroup()
            .layerEffect(
                ShaderLibrary.liquidTextEdge(
                    .float2(Float(size.width), Float(size.height)),
                    .float(liquidTime),
                    .float(3.6),
                    .float(1.35),
                    .float(18),
                    .float(1.05)
                ),
                maxSampleOffset: CGSize(width: 14, height: 14)
            )
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
                // Headroom for stronger refraction (radius × refract).
                maxSampleOffset: CGSize(width: 360, height: 360)
            )
    }

    // MARK: - Sphere stage (fixed lens + idle drift, no ping-pong)

    private func sphereStage(size: CGSize) -> some View {
        TimelineView(.animation) { context in
            // Sphere mode keeps the lens fixed at its rest anchor — no
            // idle drift / ping-pong. It only follows the finger while
            // dragging, then springs back to `restCenter`. (The
            // ping-pong wander lives in the Text stage only.)
            let restAnchor = clampedCenter(restCenter, size: size)
            let displayCenter = sphereIsDragging ? (sphereDragCenter ?? restAnchor) : restAnchor
            let shaderVelocity = sphereIsDragging ? lensVelocity : .zero
            // No idle spin in sphere mode — the `swirl` knob alone drives a
            // static rotation. (A continuous `swirlPhase` would mask the
            // knob, since a constant swirl offset is invisible on top of an
            // already-rotating field — the "swirl slider does nothing" bug.)
            let swirlPhase: Float = 0

            sphereCard(size: size)
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
                    // Headroom for stronger refraction (radius × refract can
                    // exceed 240px once Refract is cranked up).
                    maxSampleOffset: CGSize(width: 360, height: 360)
                )
                .gesture(sphereDragGesture(in: size))
        }
    }

    private func sphereCard(size: CGSize) -> some View {
        ZStack {
            Color.black

            Image("RefractiveSphere")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: size.width, maxHeight: size.height)
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: - Gestures

    private func textDragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let normalized = normalizedPoint(value.location, in: size)
                trackDragVelocity(center: normalized, at: Date())
                isDragging = true
                dragCenter = normalized
            }
            .onEnded { value in
                let normalized = normalizedPoint(value.location, in: size)
                isDragging = false
                dragCenter = nil
                previousSample = nil
                lastPhysicsTick = nil
                bubbleCenter = clampedCenter(normalized, size: size)
                bubbleVelocity = releaseVelocity(from: value.velocity, size: size)
                bubbleVelocity = cappedVelocity(bubbleVelocity)
            }
    }

    private func sphereDragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let normalized = normalizedPoint(value.location, in: size)
                if !sphereIsDragging {
                    sphereIsDragging = true
                    spherePreviousSample = nil
                }
                trackSphereVelocity(center: normalized, at: Date())
                sphereDragCenter = normalized
            }
            .onEnded { value in
                let target = normalizedPoint(value.location, in: size)
                sphereIsDragging = false
                sphereDragCenter = nil
                spherePreviousSample = nil
                lensVelocity = .zero
                // Stay exactly where the finger lifted — no spring back.
                restCenter = target
            }
    }

    // MARK: - Ping-pong physics (text)

    private func stepPhysics(at date: Date, size: CGSize) {
        if lastPhysicsTick == nil {
            lastPhysicsTick = date
            return
        }
        guard let last = lastPhysicsTick else { return }
        let dt = min(date.timeIntervalSince(last), 1.0 / 30.0)
        guard dt > 1e-5 else { return }
        lastPhysicsTick = date

        var center = bubbleCenter
        var velocity = bubbleVelocity

        center.x += velocity.x * dt
        center.y += velocity.y * dt

        let marginX = specs.glassRadius / max(size.width, 1)
        let marginY = specs.glassRadius / max(size.height, 1)
        let cornerSlack = min(marginX, marginY) * 0.35

        if center.x <= marginX {
            center.x = marginX
            velocity.x = abs(velocity.x) * bounceRestitution
        } else if center.x >= 1 - marginX {
            center.x = 1 - marginX
            velocity.x = -abs(velocity.x) * bounceRestitution
        }

        if center.y <= marginY {
            center.y = marginY
            velocity.y = abs(velocity.y) * bounceRestitution
        } else if center.y >= 1 - marginY {
            center.y = 1 - marginY
            velocity.y = -abs(velocity.y) * bounceRestitution
        }

        let nearHorizontalEdge = center.x <= marginX + cornerSlack || center.x >= 1 - marginX - cornerSlack
        let nearVerticalEdge = center.y <= marginY + cornerSlack || center.y >= 1 - marginY - cornerSlack
        if nearHorizontalEdge && nearVerticalEdge {
            velocity.x *= 1.018
            velocity.y *= 1.018
        }

        velocity.x *= velocityDamping
        velocity.y *= velocityDamping
        velocity = maintainPingPongEnergy(velocity)

        bubbleCenter = center
        bubbleVelocity = velocity
    }

    private func maintainPingPongEnergy(_ velocity: CGPoint) -> CGPoint {
        let speed = hypot(velocity.x, velocity.y)
        guard speed > 1e-4 else {
            return CGPoint(x: minPingPongSpeed * 0.86, y: minPingPongSpeed * 0.72)
        }
        if speed < minPingPongSpeed {
            let scale = minPingPongSpeed / speed
            return CGPoint(x: velocity.x * scale, y: velocity.y * scale)
        }
        if speed > maxPingPongSpeed {
            let scale = maxPingPongSpeed / speed
            return CGPoint(x: velocity.x * scale, y: velocity.y * scale)
        }
        return velocity
    }

    private func cappedVelocity(_ velocity: CGPoint) -> CGPoint {
        let speed = hypot(velocity.x, velocity.y)
        guard speed > 1e-4 else { return maintainPingPongEnergy(bubbleVelocity) }
        let boosted = max(speed, minPingPongSpeed)
        let scale = min(boosted, maxPingPongSpeed) / speed
        return CGPoint(x: velocity.x * scale, y: velocity.y * scale)
    }

    private func releaseVelocity(from velocity: CGSize, size: CGSize) -> CGPoint {
        let normalized = CGPoint(
            x: velocity.width / max(size.width, 1),
            y: velocity.height / max(size.height, 1)
        )
        if hypot(normalized.x, normalized.y) > 0.02 {
            return normalized
        }
        return dragVelocity
    }

    private func trackDragVelocity(center: CGPoint, at time: Date) {
        if let prev = previousSample {
            let dt = time.timeIntervalSince(prev.time)
            if dt > 1e-4 {
                dragVelocity = CGPoint(
                    x: (center.x - prev.center.x) / dt,
                    y: (center.y - prev.center.y) / dt
                )
            }
        }
        previousSample = (center, time)
    }

    private func trackSphereVelocity(center: CGPoint, at time: Date) {
        if let prev = spherePreviousSample {
            let dt = time.timeIntervalSince(prev.time)
            if dt > 1e-4 {
                lensVelocity = CGPoint(
                    x: (center.x - prev.center.x) / dt,
                    y: (center.y - prev.center.y) / dt
                )
            }
        }
        spherePreviousSample = (center, time)
    }

    private func normalizedPoint(_ point: CGPoint, in size: CGSize) -> CGPoint {
        clampedCenter(
            CGPoint(x: point.x / max(size.width, 1), y: point.y / max(size.height, 1)),
            size: size
        )
    }

    private func clampedCenter(_ center: CGPoint, size: CGSize) -> CGPoint {
        let marginX = specs.glassRadius / max(size.width, 1)
        let marginY = specs.glassRadius / max(size.height, 1)
        return CGPoint(
            x: min(max(center.x, marginX), 1 - marginX),
            y: min(max(center.y, marginY), 1 - marginY)
        )
    }

    private static func dripdropUIFont(size: CGFloat) -> UIFont {
        let postScript = "Dripdrop-Regular"
        return UIFont(name: postScript, size: size)
            ?? UIFont.systemFont(ofSize: size, weight: .bold)
    }

    private static func fittedDripdropSize(cardWidth: CGFloat, padding: CGFloat = textHorizontalPadding) -> CGFloat {
        let availableWidth = max(0, cardWidth - padding * 2)
        guard availableWidth > 0 else { return 100 }

        let referenceSize: CGFloat = 100
        let referenceFont = dripdropUIFont(size: referenceSize)
        let measuredWidth = (apachLabel as NSString).size(withAttributes: [.font: referenceFont]).width
        guard measuredWidth > 0 else { return referenceSize }
        return referenceSize * (availableWidth / measuredWidth)
    }

    private static func dripdropVerticalCenterOffset(fontSize: CGFloat) -> CGFloat {
        let font = dripdropUIFont(size: fontSize)
        let rect = (apachLabel as NSString).boundingRect(
            with: .zero,
            options: .usesLineFragmentOrigin,
            attributes: [.font: font],
            context: nil
        )
        return (font.lineHeight - rect.height) / 2 - rect.origin.y
    }
}

#Preview("Refractive Sphere") {
    ZStack {
        Aurora.canvas.ignoresSafeArea()
        BubbleTextRippleView(content: .sphere)
    }
}

#Preview("Refractive Text") {
    ZStack {
        Aurora.canvas.ignoresSafeArea()
        BubbleTextRippleView(
            title: "Refractive Text",
            content: .text,
            specs: BubbleTextRippleSpecs(
                ComponentSpecState(defaults: StudioItem.refractiveText.specDefaults),
                sheet: StudioItem.refractiveText.specSheet!
            )
        )
    }
}

// Card-only: just the component, full-bleed, on its own background.
#Preview("Refractive Sphere · card", traits: .sizeThatFitsLayout) {
    BubbleTextRippleView(content: .sphere, chrome: false)
        .frame(width: 430, height: 430)
}

#Preview("Refractive Text · card", traits: .sizeThatFitsLayout) {
    BubbleTextRippleView(
        title: "Refractive Text",
        content: .text,
        specs: BubbleTextRippleSpecs(
            ComponentSpecState(defaults: StudioItem.refractiveText.specDefaults),
            sheet: StudioItem.refractiveText.specSheet!
        ),
        chrome: false
    )
    .frame(width: 430, height: 430)
}
