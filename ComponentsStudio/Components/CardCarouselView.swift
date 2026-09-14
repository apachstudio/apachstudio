import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Horizontal two-card carousel copied from the Animated Credit Card, rebuilt
/// to the Figma `Untitled.fig` Bills cards: flex Credit Card + Checking Account
/// with the Figma "Moving gradient" fill, snake stroke, particles, and a
/// vertical flip (tap) that kicks up dust.
struct CardCarouselView: View {
    let specs: CardCarouselSpecs

    @State private var centeredID: FlexCardKind? = .credit
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let cardWidth = FlexCardMetrics.cardWidth(in: proxy.size)
            let cardHeight = cardWidth / FlexCardMetrics.aspectRatio
            let sideInset = max(0, (proxy.size.width - cardWidth) / 2)

            VStack(spacing: Theme.Spacing.md) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: FlexCardMetrics.cardSpacing) {
                        ForEach(FlexCardKind.allCases) { kind in
                            FlexFlipCard(
                                kind: kind,
                                specs: specs.cardSpecs(kind),
                                shared: specs,
                                size: CGSize(width: cardWidth, height: cardHeight),
                                reduceMotion: reduceMotion
                            )
                            .frame(width: cardWidth, height: cardHeight)
                            .id(kind)
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, sideInset, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                .scrollBounceBehavior(.basedOnSize)
                .scrollPosition(id: $centeredID)
                .sensoryFeedback(.selection, trigger: centeredID)
                .modifier(NoHorizontalScrollEdgeEffect())
                .frame(height: cardHeight + FlexCardMetrics.liftHeadroom)

                pageDots
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Flex card carousel")
        .accessibilityHint(
            reduceMotion
                ? "Swipe between the credit card and checking account"
                : "Swipe to move between cards. Tap a card to flip it."
        )
    }

    private var pageDots: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(FlexCardKind.allCases) { kind in
                Capsule()
                    .fill(Aurora.ink.opacity(centeredID == kind ? 0.88 : 0.18))
                    .frame(
                        width: centeredID == kind ? 18 : 8,
                        height: 8
                    )
                    .animation(FlexCardMotion.scrollSpring, value: centeredID)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            centeredID == .credit ? "Card 1 of 2, Credit Card" : "Card 2 of 2, Checking Account"
        )
    }
}

// MARK: - Card identity (Figma: "1  Credit Card" / "2 Checking Account")

enum FlexCardKind: String, CaseIterable, Identifiable, Hashable {
    case credit
    case checking

    var id: String { rawValue }

    var title: String {
        switch self {
        case .credit: return "Credit Card"
        case .checking: return "Checking Account"
        }
    }

    var accessibilityName: String {
        switch self {
        case .credit: return "flex Credit Card"
        case .checking: return "flex Checking Account"
        }
    }
}

// MARK: - Flip card

private struct FlexFlipCard: View {
    let kind: FlexCardKind
    let specs: FlexCardFaceSpecs
    let shared: CardCarouselSpecs
    let size: CGSize
    let reduceMotion: Bool

    @State private var flipTurns: Double = 0
    @State private var pressed = false

    private var flipAngle: Double { flipTurns * 180 }
    private var showingBack: Bool {
        let wrapped = abs(flipAngle.truncatingRemainder(dividingBy: 360))
        return wrapped > 90 && wrapped < 270
    }

    private var lift: CGFloat {
        guard !reduceMotion else { return 0 }
        return CGFloat(sin(flipAngle * .pi / 180.0) * shared.flipLift)
    }

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let time = reduceMotion
                ? Double(kind == .credit ? 0 : 1.8)
                : timeline.date.timeIntervalSinceReferenceDate
                    + (kind == .checking ? 1.85 : 0)

            ZStack {
                if !reduceMotion {
                    FlexCardDust(
                        size: size,
                        time: time,
                        specs: shared,
                        flipAngle: flipAngle
                    )
                }

                ZStack {
                    face(isBack: false, time: time)
                        .opacity(showingBack ? 0 : 1)
                    face(isBack: true, time: time)
                        .rotation3DEffect(.degrees(180), axis: (x: 1, y: 0, z: 0))
                        .opacity(showingBack ? 1 : 0)
                }
                .rotation3DEffect(
                    .degrees(reduceMotion ? (showingBack ? 180 : 0) : flipAngle),
                    axis: (x: 1, y: 0, z: 0),
                    perspective: CGFloat(shared.flipPerspective)
                )
                .offset(y: -lift)
                .scaleEffect(pressed ? 0.985 : 1)
                .shadow(
                    color: Color.black.opacity(0.18 + lift * 0.012),
                    radius: 10 + lift * 0.35,
                    y: 6 + lift * 0.45
                )
                .shadow(
                    color: specs.stop1.opacity(0.22 + lift * 0.01),
                    radius: 28 + lift * 0.4,
                    y: 16 + lift * 0.5
                )
            }
            .frame(width: size.width, height: size.height + FlexCardMetrics.liftHeadroom)
        }
        .scrollTransition(.animated(FlexCardMotion.scrollSpring), axis: .horizontal) { content, phase in
            let t = abs(phase.value)
            let scale: CGFloat = reduceMotion ? 1 : 1 - t * 0.08
            let opacity: CGFloat = reduceMotion ? 1 : 1 - t * 0.28
            return content
                .scaleEffect(scale)
                .opacity(opacity)
                .offset(x: reduceMotion ? 0 : phase.value * -10)
        }
        .modifier(FlexPressFlipModifier(isPressed: $pressed, onFlip: flip))
        .animation(reduceMotion ? nil : FlexCardMotion.pressSpring, value: pressed)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(kind.accessibilityName)
        .accessibilityHint("Tap to flip. Drag to move between cards.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            flip()
        }
    }

    private func face(isBack: Bool, time: Double) -> some View {
        FlexCardFace(
            kind: kind,
            isBack: isBack,
            specs: specs,
            shared: shared,
            time: time,
            size: size
        )
        .frame(width: size.width, height: size.height)
    }

    private func flip() {
        let spring = Animation.spring(
            response: shared.flipResponse,
            dampingFraction: shared.flipDamping
        )
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : spring) {
            flipTurns += 1
        }
        haptic()
    }

    private func haptic() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        #endif
    }
}

/// Press + drag stays with the parent `ScrollView`. Press + release (little
/// movement) flips the card. Same split as the vertical card deck.
private struct FlexPressFlipModifier: ViewModifier {
    @Binding var isPressed: Bool
    let onFlip: () -> Void

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed { isPressed = true }
                    }
                    .onEnded { value in
                        isPressed = false
                        let dx = abs(value.translation.width)
                        let dy = abs(value.translation.height)
                        if dx < 10 && dy < 10 { onFlip() }
                    }
            )
    }
}

// MARK: - Face

private struct FlexCardFace: View {
    let kind: FlexCardKind
    let isBack: Bool
    let specs: FlexCardFaceSpecs
    let shared: CardCarouselSpecs
    let time: Double
    let size: CGSize

    var body: some View {
        let shape = RoundedRectangle(
            cornerRadius: FlexCardMetrics.cornerRadius,
            style: .continuous
        )

        ZStack {
            FlexMovingGradientFill(specs: specs, shared: shared, time: time)
                .clipShape(shape)

            shape.fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.14),
                        Color.clear,
                        Color.black.opacity(0.22),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .blendMode(.overlay)
            .allowsHitTesting(false)

            if isBack {
                backDetails
            } else {
                frontDetails
            }

            if shared.strokeEnabled {
                FlexCardSnakeStroke(time: time, specs: shared)
            }

            shape
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.8)
        }
        .clipShape(shape)
        .contentShape(shape)
    }

    private var frontDetails: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: Theme.Spacing.sm) {
                Text("flex")
                    .font(.system(size: size.height * 0.118, weight: .bold, design: .default))
                    .tracking(-0.6)
                    .foregroundStyle(.white)
                Text(kind.title)
                    .font(.system(size: size.height * 0.062, weight: .medium))
                    .foregroundStyle(.white.opacity(0.78))
                    .padding(.top, 4)
                Spacer(minLength: 0)
                if kind == .credit {
                    MastercardMark(diameter: size.height * 0.155)
                }
            }

            Spacer(minLength: 0)

            if kind == .credit {
                creditFrontFooter
            } else {
                checkingFrontFooter
            }
        }
        .padding(.horizontal, size.width * 0.055)
        .padding(.top, size.height * 0.09)
        .padding(.bottom, size.height * 0.08)
    }

    private var creditFrontFooter: some View {
        VStack(alignment: .leading, spacing: size.height * 0.045) {
            Text("1234  5678  9012  1234")
                .font(.system(size: size.height * 0.078, weight: .regular, design: .rounded))
                .tracking(size.height * 0.012)
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            HStack(spacing: size.width * 0.10) {
                labeledValue("Exp", "08/30")
                labeledValue("CVC", "753")
                Spacer(minLength: 0)
            }
        }
    }

    private var checkingFrontFooter: some View {
        HStack(alignment: .bottom) {
            labeledValue("Account number", "003280893244")
            Spacer(minLength: Theme.Spacing.md)
            labeledValue("Routing number", "9876543212834", alignment: .trailing)
        }
    }

    private var backDetails: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.black.opacity(0.62))
                .frame(height: size.height * 0.22)
                .padding(.top, size.height * 0.12)

            Spacer(minLength: 0)

            HStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(0.82))
                    .frame(width: size.width * 0.52, height: size.height * 0.16)
                    .overlay(alignment: .leading) {
                        Text("Authorized signature")
                            .font(.system(size: size.height * 0.038, weight: .medium))
                            .italic()
                            .foregroundStyle(Color.black.opacity(0.38))
                            .padding(.leading, 10)
                    }
                Spacer(minLength: 0)
                Text(kind == .credit ? "753" : "244")
                    .font(.system(size: size.height * 0.07, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, size.width * 0.055)
            .padding(.bottom, size.height * 0.12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func labeledValue(
        _ label: String,
        _ value: String,
        alignment: HorizontalAlignment = .leading
    ) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(label)
                .font(.system(size: size.height * 0.042, weight: .medium))
                .foregroundStyle(.white.opacity(0.62))
            Text(value)
                .font(.system(size: size.height * 0.058, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
    }
}

private struct MastercardMark: View {
    let diameter: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.922, green: 0.0, blue: 0.106))
                .offset(x: -diameter * 0.28)
            Circle()
                .fill(Color(red: 0.969, green: 0.620, blue: 0.106))
                .offset(x: diameter * 0.28)
            Circle()
                .fill(Color(red: 1.0, green: 0.373, blue: 0.0).opacity(0.92))
                .frame(width: diameter * 0.42, height: diameter)
                .blendMode(.plusDarker)
        }
        .frame(width: diameter * 1.56, height: diameter)
        .accessibilityHidden(true)
    }
}

// MARK: - Moving gradient fill

private struct FlexMovingGradientFill: View {
    let specs: FlexCardFaceSpecs
    let shared: CardCarouselSpecs
    let time: Double

    var body: some View {
        GeometryReader { proxy in
            Rectangle()
                .fill(Color.black)
                .colorEffect(
                    ShaderLibrary.movingGradient(
                        .float2(Float(proxy.size.width), Float(proxy.size.height)),
                        .float(Float(time)),
                    .float4(
                        Float(shared.detail),
                        Float(shared.intensity),
                        Float(shared.warp),
                        Float(shared.twist)
                    ),
                    .float4(
                        Float(shared.morphSpeed),
                        Float(shared.rotationSpeed),
                        Float(shared.zoom),
                        Float(shared.gradientBalance)
                    ),
                    .float4(
                        Float(shared.material),
                        Float(shared.gradientMethod),
                        3,
                        0
                    ),
                    specs.stop0.shaderStop(position: 0.0),
                    specs.stop1.shaderStop(position: 0.5),
                    specs.stop2.shaderStop(position: 1.0),
                    specs.stop2.shaderStop(position: 1.0)
                    )
                )
                .allowsHitTesting(false)
        }
    }
}

private extension Color {
    func shaderStop(position: Float) -> Shader.Argument {
        #if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return .float4(Float(r), Float(g), Float(b), position)
        #else
        return .float4(1, 1, 1, position)
        #endif
    }
}

// MARK: - Snake stroke (kept from the original card)

private struct FlexCardSnakeStroke: View {
    let time: Double
    let specs: CardCarouselSpecs

    private var phase: CGFloat {
        CGFloat(FlexCardMotion.strokePhase(
            at: time,
            period: specs.auraPeriod,
            ease: specs.strokeEase,
            spring: specs.strokeSpring
        ))
    }

    private var end: CGFloat { phase + CGFloat(specs.strokeLength) }

    var body: some View {
        ZStack {
            strokeSegment(from: phase, to: min(end, 1))
            if end > 1 {
                strokeSegment(from: 0, to: end - 1)
            }
        }
        .allowsHitTesting(false)
    }

    private func strokeSegment(from start: CGFloat, to end: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: FlexCardMetrics.cornerRadius, style: .continuous)
            .trim(from: start, to: end)
            .stroke(
                AngularGradient(
                    gradient: Gradient(colors: specs.strokeColors + [specs.strokeColors[0]]),
                    center: .center,
                    angle: .degrees(FlexCardMotion.angle(at: time, period: specs.auraPeriod))
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

// MARK: - Dust / particles

private struct FlexCardDust: View {
    let size: CGSize
    let time: Double
    let specs: CardCarouselSpecs
    let flipAngle: Double

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
        let age = FlexDustSpecs.age(for: index, at: time)
        let life = (FlexDustSpecs.duration - age) / FlexDustSpecs.duration
        let easedDecay = pow(life, FlexDustSpecs.decayExponent)
        let origin = FlexDustSpecs.origin(for: index, size: size)
        let spread = FlexDustSpecs.signedRandom(index, salt: 2) * specs.particleSpread
        let radians = flipAngle * .pi / 180.0
        let liftAmount = abs(sin(radians))
        let tableKick = abs(cos(radians)) * (liftAmount > 0.02 ? 1.0 : 0.0)
        let kick = tableKick * specs.dustAmount
        let liftKick = liftAmount * specs.dustAmount
        let direction = Double.pi / 2 + spread * (1 + kick * 0.65)
        let speed = FlexDustSpecs.speed(for: index, maximum: specs.particleSpeed)
            * (1 + kick * 1.35 + liftKick * 0.55)
        let diameter = FlexDustSpecs.diameter(for: index, maximum: specs.particleSize)
            * (1 + liftKick * 0.25)
        let opacity = FlexDustSpecs.opacity(for: index)
        let palette = specs.strokeColors
        let colorIndex = Int(FlexDustSpecs.random(index, salt: 5) * Double(palette.count))
            % max(palette.count, 1)
        let color = palette[colorIndex]
        let gravity = specs.particleGravity - kick * 110 - liftKick * 55

        return Circle()
            .fill(color)
            .frame(width: diameter, height: diameter)
            .scaleEffect(0.40 + easedDecay * 0.70)
            .opacity(easedDecay * opacity * (0.85 + kick * 0.45))
            .modifier(
                FlexDustMotion(
                    time: age,
                    origin: origin,
                    speed: speed,
                    angle: direction,
                    gravity: gravity
                )
            )
            .shadow(color: color.opacity(0.40), radius: diameter)
            .blendMode(.plusLighter)
    }
}

private struct FlexDustMotion: GeometryEffect {
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
        let dy = speed * sin(angle) * time - 0.5 * gravity * time * time
        return ProjectionTransform(
            CGAffineTransform(
                translationX: origin.x + CGFloat(dx),
                y: origin.y - CGFloat(dy)
            )
        )
    }
}

private enum FlexDustSpecs {
    static let duration: Double = 2.6
    static let decayExponent: Double = 0.62
    static let minimumSpeed: Double = 40
    static let horizontalStart: Double = 0.12
    static let horizontalSpan: Double = 0.76
    static let verticalJitter: Double = 10
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
        return CGFloat(minimumDiameter + random(index, salt: 6) * (top - minimumDiameter))
    }

    static func opacity(for index: Int) -> Double {
        minimumOpacity + random(index, salt: 7) * (maximumOpacity - minimumOpacity)
    }

    static func origin(for index: Int, size: CGSize) -> CGPoint {
        let horizontalFraction = horizontalStart + random(index, salt: 1) * horizontalSpan
        return CGPoint(
            x: (horizontalFraction - 0.5) * size.width,
            y: size.height / 2 + CGFloat(random(index, salt: 8) * verticalJitter)
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

// MARK: - Motion / metrics

private enum FlexCardMotion {
    static let scrollSpring: Animation = .spring(response: 0.55, dampingFraction: 0.78)
    static let pressSpring: Animation = .spring(response: 0.28, dampingFraction: 0.95)

    static func phase(at time: Double, period: Double) -> Double {
        guard period > 0 else { return 0 }
        return time.truncatingRemainder(dividingBy: period) / period
    }

    static func strokePhase(at time: Double, period: Double, ease: Double, spring: Double) -> Double {
        let linear = phase(at: time, period: period)
        let eased = linear * linear * linear * (linear * (linear * 6 - 15) + 10)
        let easedPhase = linear + (eased - linear) * ease
        let springWave = sin(easedPhase * .pi * 2) * sin(easedPhase * .pi)
        return wrapped(easedPhase + springWave * spring * 0.08)
    }

    static func angle(at time: Double, period: Double) -> Double {
        phase(at: time, period: period) * 360
    }

    private static func wrapped(_ value: Double) -> Double {
        let remainder = value.truncatingRemainder(dividingBy: 1)
        return remainder >= 0 ? remainder : remainder + 1
    }
}

private enum FlexCardMetrics {
    /// ISO/IEC 7810 ID-1, matching the Figma landscape cards.
    static let aspectRatio: CGFloat = 1.586
    static let cornerRadius: CGFloat = 32
    static let cardSpacing: CGFloat = 16
    static let liftHeadroom: CGFloat = 28

    static func cardWidth(in available: CGSize) -> CGFloat {
        min(available.width * 0.86, 402 - 48)
    }
}

private struct NoHorizontalScrollEdgeEffect: ViewModifier {
    func body(content: Content) -> some View {
        content.scrollEdgeEffectHidden(true, for: [.leading, .trailing])
    }
}

// MARK: - Preview

private struct CardCarouselPreviewHost: View {
    @State private var state: ComponentSpecState

    init() {
        _state = State(initialValue: ComponentSpecState(
            defaults: StudioItem.cardCarousel.specDefaults
        ))
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            CardCarouselView(
                specs: CardCarouselSpecs(
                    state,
                    sheet: StudioItem.cardCarousel.specSheet!
                )
            )
            .padding(.horizontal, Theme.Spacing.lg)
        }
    }
}

#Preview("Card carousel") {
    CardCarouselPreviewHost()
}
