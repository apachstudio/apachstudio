import SwiftUI

/// A dimensional credit card with the AI Search pill's rotating snake stroke
/// and a perimeter-adapted version of the supplied projectile particle effect.
struct AnimatedCreditCardView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var specs = AnimatedCreditCardSpecs()

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            GeometryReader { proxy in
                let cardSize = CreditCardMetrics.cardSize(in: proxy.size)
                let time = reduceMotion
                    ? 0
                    : timeline.date.timeIntervalSinceReferenceDate

                ZStack {
                    creditCard(size: cardSize, time: time)

                    if !reduceMotion {
                        CreditCardParticles(size: cardSize, time: time, specs: specs)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .aspectRatio(CreditCardMetrics.stageAspectRatio, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Animated purple credit card")
        .accessibilityValue("Christopher Wallace")
    }

    private func creditCard(size: CGSize, time: Double) -> some View {
        CreditCardFace()
            .frame(width: size.width, height: size.height)
            .overlay {
                CreditCardAura(time: time, specs: specs)
            }
            .overlay {
                CreditCardSnakeStroke(time: time, specs: specs)
            }
            .shadow(
                color: CreditCardPalette.shadow.opacity(0.34),
                radius: CreditCardMetrics.contactShadowRadius,
                y: CreditCardMetrics.contactShadowOffset
            )
            .shadow(
                color: CreditCardPalette.shadow.opacity(0.22),
                radius: CreditCardMetrics.ambientShadowRadius,
                y: CreditCardMetrics.ambientShadowOffset
            )
    }
}

private struct CreditCardFace: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let cardShape = RoundedRectangle(
                cornerRadius: CreditCardMetrics.cornerRadius,
                style: .continuous
            )

            ZStack {
                cardShape
                    .fill(CreditCardPalette.body)

                cardShape
                    .fill(CreditCardPalette.surfaceLight)
                    .blendMode(.screen)

                cardShape
                    .fill(CreditCardPalette.edgeShade)
                    .blendMode(.multiply)

                cardShape
                    .strokeBorder(CreditCardPalette.outerEdge, lineWidth: 1)

                cardShape
                    .inset(by: CreditCardMetrics.innerBorderInset)
                    .strokeBorder(CreditCardPalette.innerEdge, lineWidth: 1)

                cardDetails(size: size)
            }
            .clipShape(cardShape)
        }
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
                gradient: Gradient(
                    colors: CreditCardPalette.aiStops + [CreditCardPalette.aiStops[0]]
                ),
                center: .center,
                angle: .degrees(CreditCardMotion.angle(at: time, period: specs.strokePeriod))
            )
        )
        .blur(radius: CGFloat(specs.auraBlurRadius))
        .opacity(specs.auraOpacity)
        .allowsHitTesting(false)
    }
}

private struct CreditCardSnakeStroke: View {
    let time: Double
    let specs: AnimatedCreditCardSpecs

    var body: some View {
        RoundedRectangle(
            cornerRadius: CreditCardMetrics.cornerRadius,
            style: .continuous
        )
        .strokeBorder(
            AngularGradient(
                gradient: Gradient(stops: CreditCardPalette.snakeStops),
                center: .center,
                angle: .degrees(CreditCardMotion.angle(at: time, period: specs.strokePeriod))
            ),
            lineWidth: CGFloat(specs.strokeWidth)
        )
        .overlay {
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
}

private struct CreditCardParticles: View {
    let size: CGSize
    let time: Double
    let specs: AnimatedCreditCardSpecs

    var body: some View {
        ZStack {
            ForEach(0..<max(1, Int(specs.particleCount.rounded())), id: \.self) { index in
                particle(index: index)
            }
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func particle(index: Int) -> some View {
        let age = CreditCardParticleSpecs.age(
            for: index,
            at: time,
            duration: specs.particleDuration
        )
        let life = (specs.particleDuration - age)
            / specs.particleDuration
        let origin = CreditCardParticleSpecs.origin(
            for: index,
            size: size
        )
        let spread = CreditCardParticleSpecs.signedRandom(index, salt: 2)
            * specs.particleSpreadDegrees * .pi / 180
        let direction = Double.pi / 2 + spread
        let speed = CreditCardParticleSpecs.speed(
            for: index,
            minimum: min(specs.minimumSpeed, specs.maximumSpeed),
            maximum: max(specs.minimumSpeed, specs.maximumSpeed)
        )
        let diameter = CreditCardParticleSpecs.diameter(for: index)
        let opacity = CreditCardParticleSpecs.opacity(
            for: index,
            maximum: specs.maximumOpacity
        )
        let colorIndex = Int(
            CreditCardParticleSpecs.random(index, salt: 5)
                * Double(CreditCardPalette.particleColors.count)
        ) % CreditCardPalette.particleColors.count
        let color = CreditCardPalette.particleColors[colorIndex]

        return Circle()
            .fill(color)
            .frame(width: diameter, height: diameter)
            .scaleEffect(life)
            .opacity(life * opacity)
            .modifier(
                CreditCardParticleMotion(
                    time: age,
                    origin: origin,
                    speed: speed,
                    angle: direction,
                    gravity: specs.gravity
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

    static func angle(at time: Double, period: Double) -> Double {
        time.truncatingRemainder(dividingBy: period) / period * 360
    }
}

private enum CreditCardParticleSpecs {
    // The reference clusters tiny motes in the middle 64% above the button.
    static let horizontalStart: Double = 0.18
    static let horizontalSpan: Double = 0.64
    static let verticalJitter: Double = 8
    static let minimumDiameter: Double = 0.8
    static let maximumDiameter: Double = 2.2
    static let minimumOpacity: Double = 0.16

    static func age(for index: Int, at time: Double, duration: Double) -> Double {
        let delay = random(index, salt: 3) * duration
        return (time + delay).truncatingRemainder(dividingBy: duration)
    }

    static func speed(for index: Int, minimum: Double, maximum: Double) -> Double {
        minimum + random(index, salt: 4) * (maximum - minimum)
    }

    static func diameter(for index: Int) -> CGFloat {
        CGFloat(
            minimumDiameter
                + random(index, salt: 6) * (maximumDiameter - minimumDiameter)
        )
    }

    static func opacity(for index: Int, maximum: Double) -> Double {
        minimumOpacity
            + random(index, salt: 7) * (maximum - minimumOpacity)
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
    static let aiStops: [Color] = [
        Color(red: 0.40, green: 0.30, blue: 1.00),
        Color(red: 0.74, green: 0.38, blue: 1.00),
        Color(red: 1.00, green: 0.45, blue: 0.62),
        Color(red: 1.00, green: 0.62, blue: 0.40),
    ]

    static let snakeStops: [Gradient.Stop] = [
        .init(color: .white, location: 0.00),
        .init(color: aiStops[2], location: 0.05),
        .init(color: aiStops[1], location: 0.14),
        .init(color: aiStops[1].opacity(0), location: 0.30),
        .init(color: .clear, location: 1.00),
    ]
    static let particleColors: [Color] = [
        .white,
        aiStops[0],
        aiStops[1],
    ]

    static let body = LinearGradient(
        colors: [
            Color(red: 0.13, green: 0.06, blue: 0.28),
            Color(red: 0.08, green: 0.035, blue: 0.19),
            Color(red: 0.12, green: 0.05, blue: 0.25),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let surfaceLight = RadialGradient(
        colors: [
            Color(red: 0.52, green: 0.35, blue: 0.90).opacity(0.18),
            .clear,
        ],
        center: UnitPoint(x: 0.72, y: 0.10),
        startRadius: 0,
        endRadius: 360
    )
    static let edgeShade = LinearGradient(
        colors: [.clear, Color.black.opacity(0.34)],
        startPoint: .top,
        endPoint: .bottom
    )
    static let outerEdge = LinearGradient(
        colors: [
            Color.white.opacity(0.42),
            Color(red: 0.55, green: 0.34, blue: 1).opacity(0.76),
            Color.black.opacity(0.70),
        ],
        startPoint: .topTrailing,
        endPoint: .bottomLeading
    )
    static let innerEdge = LinearGradient(
        colors: [
            Color.white.opacity(0.25),
            Color(red: 0.48, green: 0.28, blue: 0.90).opacity(0.18),
            Color.black.opacity(0.42),
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    static let embossedDark = Color(red: 0.025, green: 0.012, blue: 0.06)
    static let embossedLight = Color(red: 0.49, green: 0.34, blue: 0.82).opacity(0.40)
    static let shadow = Color(red: 0.08, green: 0.025, blue: 0.18)
}

#Preview("Animated credit card") {
    ZStack {
        Color(.systemBackground).ignoresSafeArea()
        AnimatedCreditCardView()
            .padding(Theme.Spacing.xl)
    }
}
