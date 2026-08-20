import SwiftUI

/// A dimensional animated credit card with draggable 3D tilt, a rounded-cap
/// snake stroke, glow, and projectile particles.
struct AnimatedCreditCardView: View {
    let specs: AnimatedCreditCardSpecs

    @GestureState private var dragTranslation: CGSize = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var tiltX: Double {
        guard !reduceMotion, specs.rotationEnabled else { return 0 }
        return clamped(-Double(dragTranslation.height) / 12, -specs.maxTilt, specs.maxTilt)
    }

    private var tiltY: Double {
        guard !reduceMotion, specs.rotationEnabled else { return 0 }
        return clamped(Double(dragTranslation.width) / 12, -specs.maxTilt, specs.maxTilt)
    }

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            GeometryReader { proxy in
                let cardSize = CreditCardMetrics.cardSize(in: proxy.size)
                let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate

                ZStack {
                    creditCard(size: cardSize, time: time)

                    if !reduceMotion {
                        CreditCardParticles(size: cardSize, time: time, specs: specs)
                    }
                }
                .rotation3DEffect(
                    .degrees(tiltX),
                    axis: (x: 1, y: 0, z: 0),
                    perspective: CGFloat(specs.perspective)
                )
                .rotation3DEffect(
                    .degrees(tiltY),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: CGFloat(specs.perspective)
                )
                .animation(
                    reduceMotion ? nil : CreditCardMotion.tiltSpring,
                    value: dragTranslation
                )
                .gesture(tiltGesture)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .aspectRatio(CreditCardMetrics.stageAspectRatio, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Animated purple credit card")
        .accessibilityValue("Christopher Wallace")
        .accessibilityHint(
            reduceMotion
                ? "Three-dimensional motion is disabled by Reduce Motion"
                : "Drag to tilt the card in three dimensions"
        )
    }

    private func creditCard(size: CGSize, time: Double) -> some View {
        ZStack {
            CreditCardEdge(specs: specs)
                .frame(width: size.width, height: size.height)
                .offset(y: CGFloat(specs.cardDepth))

            CreditCardFace(specs: specs, tiltX: tiltX, tiltY: tiltY)
                .frame(width: size.width, height: size.height)
                .overlay {
                    CreditCardAura(time: time, specs: specs)
                }
                .overlay {
                    CreditCardSnakeStroke(time: time, specs: specs)
                }
        }
        .frame(width: size.width, height: size.height + CGFloat(specs.cardDepth))
        .shadow(
            color: CreditCardPalette.shadow.opacity(0.34),
            radius: CreditCardMetrics.contactShadowRadius + CGFloat(specs.cardDepth * 0.35),
            y: CreditCardMetrics.contactShadowOffset + CGFloat(specs.cardDepth * 0.35)
        )
        .shadow(
            color: CreditCardPalette.shadow.opacity(0.22),
            radius: CreditCardMetrics.ambientShadowRadius,
            y: CreditCardMetrics.ambientShadowOffset
        )
    }

    private var tiltGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .updating($dragTranslation) { value, state, _ in
                state = value.translation
            }
    }

    private func clamped(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        max(lower, min(upper, value))
    }
}

private struct CreditCardFace: View {
    let specs: AnimatedCreditCardSpecs
    let tiltX: Double
    let tiltY: Double

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let cardShape = RoundedRectangle(
                cornerRadius: CreditCardMetrics.cornerRadius,
                style: .continuous
            )

            ZStack {
                cardShape
                    .fill(cardGradient)

                cardShape
                    .fill(CreditCardPalette.surfaceLight(specs: specs))
                    .blendMode(.screen)

                if specs.texture > 0 {
                    CreditCardTexture(opacity: specs.texture)
                        .clipShape(cardShape)
                }

                cardShape
                    .fill(CreditCardPalette.edgeShade)
                    .blendMode(.multiply)

                if specs.glossiness > 0 {
                    CreditCardGloss(
                        opacity: specs.glossiness,
                        tiltX: tiltX,
                        tiltY: tiltY,
                        maximumTilt: specs.maxTilt
                    )
                        .clipShape(cardShape)
                        .blendMode(.screen)
                }

                cardShape
                    .strokeBorder(CreditCardPalette.outerEdge(specs: specs), lineWidth: 1)

                cardShape
                    .inset(by: CreditCardMetrics.innerBorderInset)
                    .strokeBorder(CreditCardPalette.innerEdge(specs: specs), lineWidth: 1)

                cardDetails(size: size)
            }
            .clipShape(cardShape)
        }
    }

    private var cardGradient: LinearGradient {
        LinearGradient(
            colors: [specs.cardTopColor, specs.cardMidColor, specs.cardBottomColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func cardDetails(size: CGSize) -> some View {
        ZStack {
            brandMark(size: size)
                .position(x: size.width * 0.87, y: size.height * 0.19)

            signatureSlots(size: size)

            verificationDots(size: size)

            embossedName(size: size)
                .position(x: size.width * 0.25, y: size.height * 0.91)
        }
    }

    private func brandMark(size: CGSize) -> some View {
        let diameter = size.height * 0.18

        return ZStack {
            embossedCircle(diameter: diameter)
                .offset(x: -diameter * 0.28)
            embossedCircle(diameter: diameter)
                .offset(x: diameter * 0.28)
        }
        .frame(width: diameter * 1.6, height: diameter)
    }

    private func embossedCircle(diameter: CGFloat) -> some View {
        Circle()
            .stroke(CreditCardPalette.embossedDark, lineWidth: 2)
            .overlay {
                Circle()
                    .stroke(CreditCardPalette.embossedLight, lineWidth: 1)
                    .offset(y: -0.5)
            }
            .frame(width: diameter, height: diameter)
    }

    private func signatureSlots(size: CGSize) -> some View {
        HStack(spacing: size.width * 0.035) {
            embossedSlot(width: size.width * 0.22, height: size.height * 0.037)
            embossedSlot(width: size.width * 0.20, height: size.height * 0.037)
        }
        .position(x: size.width * 0.31, y: size.height * 0.72)
    }

    private func embossedSlot(width: CGFloat, height: CGFloat) -> some View {
        Capsule()
            .fill(CreditCardPalette.embossedDark.opacity(0.72))
            .overlay {
                Capsule()
                    .stroke(CreditCardPalette.embossedLight, lineWidth: 1)
                    .offset(y: -0.5)
            }
            .frame(width: width, height: height)
    }

    private func verificationDots(size: CGSize) -> some View {
        HStack(spacing: size.width * 0.019) {
            ForEach(0..<18, id: \.self) { _ in
                Circle()
                    .fill(CreditCardPalette.embossedDark.opacity(0.76))
                    .overlay {
                        Circle()
                            .stroke(CreditCardPalette.embossedLight, lineWidth: 0.7)
                            .offset(y: -0.4)
                    }
                    .frame(width: size.height * 0.038)
            }
        }
        .position(x: size.width * 0.44, y: size.height * 0.82)
    }

    private func embossedName(size: CGSize) -> some View {
        Text("CHRISTOPHER WALLACE")
            .font(.system(size: size.height * 0.037, weight: .medium, design: .rounded))
            .tracking(size.height * 0.012)
            .foregroundStyle(CreditCardPalette.embossedDark.opacity(0.72))
            .shadow(
                color: CreditCardPalette.embossedLight,
                radius: 0,
                y: -0.8
            )
            .lineLimit(1)
    }
}

private struct CreditCardEdge: View {
    let specs: AnimatedCreditCardSpecs

    var body: some View {
        RoundedRectangle(cornerRadius: CreditCardMetrics.cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        specs.cardBottomColor.opacity(0.82),
                        Color.black.opacity(0.72),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: CreditCardMetrics.cornerRadius, style: .continuous)
                    .strokeBorder(specs.glowStartColor.opacity(0.16), lineWidth: 1)
            }
    }
}

private struct CreditCardTexture: View {
    let opacity: Double

    var body: some View {
        Canvas { context, size in
            for index in 0..<90 {
                let x = random(index, salt: 1) * size.width
                let y = random(index, salt: 2) * size.height
                let width = 8 + random(index, salt: 3) * 24
                let alpha = opacity * (0.012 + random(index, salt: 4) * 0.035)
                let rect = CGRect(x: x, y: y, width: width, height: 0.7)
                context.fill(Path(rect), with: .color(.white.opacity(alpha)))
            }
        }
        .allowsHitTesting(false)
    }

    private func random(_ index: Int, salt: Int) -> CGFloat {
        let value = sin(Double(index * 73 + salt * 997) * 12.9898) * 43758.5453
        return CGFloat(value - floor(value))
    }
}

private struct CreditCardGloss: View {
    let opacity: Double
    let tiltX: Double
    let tiltY: Double
    let maximumTilt: Double

    private var normalizedX: Double {
        guard maximumTilt > 0 else { return 0 }
        return max(-1, min(1, tiltY / maximumTilt))
    }

    private var normalizedY: Double {
        guard maximumTilt > 0 else { return 0 }
        return max(-1, min(1, tiltX / maximumTilt))
    }

    private var highlightCenter: UnitPoint {
        UnitPoint(
            x: CGFloat(0.5 - normalizedX * 0.32),
            y: CGFloat(0.5 + normalizedY * 0.24)
        )
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    .white.opacity(0.34 * opacity),
                    .white.opacity(0.06 * opacity),
                    .clear,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    .white.opacity(0.30 * opacity),
                    .white.opacity(0.08 * opacity),
                    .clear,
                ],
                center: highlightCenter,
                startRadius: 0,
                endRadius: 150
            )
        }
        .allowsHitTesting(false)
    }
}

private struct CreditCardAura: View {
    let time: Double
    let specs: AnimatedCreditCardSpecs

    var body: some View {
        RoundedRectangle(
            cornerRadius: CreditCardMetrics.cornerRadius,
            style: .continuous
        )
        .fill(
            AngularGradient(
                gradient: Gradient(colors: specs.glowGradientColors + [specs.glowGradientColors[0]]),
                center: .center,
                angle: .degrees(CreditCardMotion.angle(at: time, period: specs.auraPeriod))
            )
        )
        .blur(radius: specs.auraBlur)
        .opacity(specs.auraOpacity)
        .allowsHitTesting(false)
    }
}

private struct CreditCardSnakeStroke: View {
    let time: Double
    let specs: AnimatedCreditCardSpecs

    private var phase: CGFloat {
        CGFloat(CreditCardMotion.strokePhase(
            at: time,
            period: specs.auraPeriod,
            ease: specs.strokeEase,
            spring: specs.strokeSpring
        ))
    }

    private var end: CGFloat {
        phase + CGFloat(specs.strokeLength)
    }

    var body: some View {
        ZStack {
            strokeSegment(from: phase, to: min(end, 1))
            if end > 1 {
                strokeSegment(from: 0, to: end - 1)
            }

            RoundedRectangle(
                cornerRadius: CreditCardMetrics.cornerRadius,
                style: .continuous
            )
            .strokeBorder(
                Color.white.opacity(CreditCardMotion.highlightOpacity),
                lineWidth: CreditCardMotion.highlightWidth
            )
        }
        .allowsHitTesting(false)
    }

    private func strokeSegment(from start: CGFloat, to end: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: CreditCardMetrics.cornerRadius, style: .continuous)
            .trim(from: start, to: end)
            .stroke(
                AngularGradient(
                    gradient: Gradient(colors: specs.strokeGradientColors + [specs.strokeGradientColors[0]]),
                    center: .center,
                    angle: .degrees(CreditCardMotion.angle(at: time, period: specs.auraPeriod))
                ),
                style: StrokeStyle(
                    lineWidth: CGFloat(specs.snakeWidth),
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .padding(CGFloat(specs.snakeWidth) / 2)
    }
}

private struct CreditCardParticles: View {
    let size: CGSize
    let time: Double
    let specs: AnimatedCreditCardSpecs

    var body: some View {
        ZStack {
            ForEach(0..<specs.particleCount, id: \.self) { index in
                particle(index: index)
            }
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func particle(index: Int) -> some View {
        let age = CreditCardParticleSpecs.age(for: index, at: time)
        let life = (CreditCardParticleSpecs.duration - age)
            / CreditCardParticleSpecs.duration
        let easedDecay = pow(life, CreditCardParticleSpecs.decayExponent)
        let origin = CreditCardParticleSpecs.origin(
            for: index,
            size: size
        )
        let spread = CreditCardParticleSpecs.signedRandom(index, salt: 2)
            * specs.particleSpread
        let direction = Double.pi / 2 + spread
        let speed = CreditCardParticleSpecs.speed(for: index, maximum: specs.particleSpeed)
        let diameter = CreditCardParticleSpecs.diameter(for: index, maximum: specs.particleSize)
        let opacity = CreditCardParticleSpecs.opacity(for: index)
        let colorIndex = Int(
            CreditCardParticleSpecs.random(index, salt: 5)
                * Double(specs.glowGradientColors.count)
        ) % specs.glowGradientColors.count
        let color = specs.glowGradientColors[colorIndex]

        return Circle()
            .fill(color)
            .frame(width: diameter, height: diameter)
            .scaleEffect(0.45 + easedDecay * 0.55)
            .opacity(easedDecay * opacity)
            .modifier(
                CreditCardParticleMotion(
                    time: age,
                    origin: origin,
                    speed: speed,
                    angle: direction,
                    gravity: specs.particleGravity
                )
            )
            .shadow(color: color.opacity(0.42), radius: diameter)
            .blendMode(.plusLighter)
    }
}

private struct CreditCardParticleMotion: GeometryEffect {
    var time: Double
    let origin: CGPoint
    let speed: Double
    let angle: Double
    let gravity: Double

    var animatableData: Double {
        get { time }
        set { time = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let dx = speed * time * cos(angle)
        let dy = speed * sin(angle) * time
            - 0.5 * gravity * time * time
        let transform = CGAffineTransform(
            translationX: origin.x + CGFloat(dx),
            y: origin.y - CGFloat(dy)
        )
        return ProjectionTransform(transform)
    }
}

private enum CreditCardMotion {
    static let highlightOpacity: Double = 0.06
    static let highlightWidth: CGFloat = 0.5
    static let tiltSpring: Animation = .spring(response: 0.50, dampingFraction: 0.86)

    static func phase(at time: Double, period: Double) -> Double {
        guard period > 0 else { return 0 }
        return time.truncatingRemainder(dividingBy: period) / period
    }

    static func strokePhase(at time: Double, period: Double, ease: Double, spring: Double) -> Double {
        let linear = phase(at: time, period: period)
        let eased = smootherStep(linear)
        let easedPhase = linear + (eased - linear) * ease
        let springWave = sin(easedPhase * .pi * 2) * sin(easedPhase * .pi)
        return wrapped(easedPhase + springWave * spring * 0.08)
    }

    static func angle(at time: Double, period: Double) -> Double {
        phase(at: time, period: period) * 360
    }

    private static func smootherStep(_ value: Double) -> Double {
        value * value * value * (value * (value * 6 - 15) + 10)
    }

    private static func wrapped(_ value: Double) -> Double {
        let remainder = value.truncatingRemainder(dividingBy: 1)
        return remainder >= 0 ? remainder : remainder + 1
    }
}

private enum CreditCardParticleSpecs {
    static let duration: Double = 2.6
    static let decayExponent: Double = 0.62
    static let minimumSpeed: Double = 40
    static let horizontalStart: Double = 0.18
    static let horizontalSpan: Double = 0.64
    static let verticalJitter: Double = 8
    static let minimumDiameter: Double = 0.8
    static let minimumOpacity: Double = 0.16
    static let maximumOpacity: Double = 0.48

    static func age(for index: Int, at time: Double) -> Double {
        let delay = random(index, salt: 3) * duration
        return (time + delay).truncatingRemainder(dividingBy: duration)
    }

    static func speed(for index: Int, maximum: Double) -> Double {
        let top = max(minimumSpeed, maximum)
        return minimumSpeed + random(index, salt: 4) * (top - minimumSpeed)
    }

    static func diameter(for index: Int, maximum: Double) -> CGFloat {
        let top = max(minimumDiameter, maximum)
        return CGFloat(
            minimumDiameter + random(index, salt: 6) * (top - minimumDiameter)
        )
    }

    static func opacity(for index: Int) -> Double {
        minimumOpacity
            + random(index, salt: 7) * (maximumOpacity - minimumOpacity)
    }

    static func origin(for index: Int, size: CGSize) -> CGPoint {
        let horizontalFraction = horizontalStart
            + random(index, salt: 1) * horizontalSpan
        return CGPoint(
            x: (horizontalFraction - 0.5) * size.width,
            y: -size.height / 2
                - CGFloat(random(index, salt: 8) * verticalJitter)
        )
    }

    static func signedRandom(_ index: Int, salt: UInt64) -> Double {
        random(index, salt: salt) * 2 - 1
    }

    static func random(_ index: Int, salt: UInt64) -> Double {
        var value = UInt64(index + 1) &* 0x9E3779B97F4A7C15
        value &+= salt &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        value ^= value >> 31
        return Double(value & 0x00FF_FFFF) / Double(0x0100_0000)
    }
}

private enum CreditCardMetrics {
    static let cardAspectRatio: CGFloat = 1.72
    static let stageAspectRatio: CGFloat = 1.34
    static let cornerRadius = Theme.Radius.card
    static let innerBorderInset: CGFloat = 4
    static let contactShadowRadius: CGFloat = 8
    static let contactShadowOffset: CGFloat = 4
    static let ambientShadowRadius: CGFloat = 24
    static let ambientShadowOffset: CGFloat = 16

    static func cardSize(in available: CGSize) -> CGSize {
        let width = min(
            available.width * 0.84,
            available.height * cardAspectRatio * 0.62
        )
        return CGSize(width: width, height: width / cardAspectRatio)
    }
}

private enum CreditCardPalette {
    static let edgeShade = LinearGradient(
        colors: [.clear, Color.black.opacity(0.34)],
        startPoint: .top,
        endPoint: .bottom
    )
    static let embossedDark = Color(red: 0.025, green: 0.012, blue: 0.06)
    static let embossedLight = Color(red: 0.49, green: 0.34, blue: 0.82).opacity(0.40)
    static let shadow = Color(red: 0.08, green: 0.025, blue: 0.18)

    static func surfaceLight(specs: AnimatedCreditCardSpecs) -> RadialGradient {
        RadialGradient(
            colors: [specs.glowMidColor.opacity(0.18), .clear],
            center: UnitPoint(x: 0.72, y: 0.10),
            startRadius: 0,
            endRadius: 360
        )
    }

    static func outerEdge(specs: AnimatedCreditCardSpecs) -> LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.42),
                specs.strokeMidColor.opacity(0.76),
                Color.black.opacity(0.70),
            ],
            startPoint: .topTrailing,
            endPoint: .bottomLeading
        )
    }

    static func innerEdge(specs: AnimatedCreditCardSpecs) -> LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.25),
                specs.strokeStartColor.opacity(0.18),
                Color.black.opacity(0.42),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private extension AnimatedCreditCardSpecs {
    var strokeStartColor: Color { color("strokeStart") }
    var strokeMidColor: Color { color("strokeMid") }
    var strokeEndColor: Color { color("strokeEnd") }
    var glowStartColor: Color { color("glowStart") }
    var glowMidColor: Color { color("glowMid") }
    var glowEndColor: Color { color("glowEnd") }
    var cardTopColor: Color { color("cardTop") }
    var cardMidColor: Color { color("cardMid") }
    var cardBottomColor: Color { color("cardBottom") }

    var strokeGradientColors: [Color] { [strokeStartColor, strokeMidColor, strokeEndColor] }
    var glowGradientColors: [Color] { [glowStartColor, glowMidColor, glowEndColor] }

    private func color(_ prefix: String) -> Color {
        switch prefix {
        case "strokeStart": return Color(red: strokeStartR, green: strokeStartG, blue: strokeStartB)
        case "strokeMid": return Color(red: strokeMidR, green: strokeMidG, blue: strokeMidB)
        case "strokeEnd": return Color(red: strokeEndR, green: strokeEndG, blue: strokeEndB)
        case "glowStart": return Color(red: glowStartR, green: glowStartG, blue: glowStartB)
        case "glowMid": return Color(red: glowMidR, green: glowMidG, blue: glowMidB)
        case "glowEnd": return Color(red: glowEndR, green: glowEndG, blue: glowEndB)
        case "cardTop": return Color(red: cardTopR, green: cardTopG, blue: cardTopB)
        case "cardMid": return Color(red: cardMidR, green: cardMidG, blue: cardMidB)
        default: return Color(red: cardBottomR, green: cardBottomG, blue: cardBottomB)
        }
    }
}

/// Renders the card at its registered defaults, outside the studio stage.
private struct CreditCardPreviewHost: View {
    @State private var state: ComponentSpecState

    init() {
        _state = State(initialValue: ComponentSpecState(
            defaults: StudioItem.animatedCreditCard.specDefaults
        ))
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            AnimatedCreditCardView(
                specs: AnimatedCreditCardSpecs(
                    state,
                    sheet: StudioItem.animatedCreditCard.specSheet!
                )
            )
            .padding(Theme.Spacing.xl)
        }
    }
}

#Preview("Animated credit card") {
    CreditCardPreviewHost()
}
