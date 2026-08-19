import SwiftUI

/// A dimensional credit card with the AI Search rim treatment. Drag to tilt;
/// release to let the card settle back to its resting perspective.
struct CreditCard3DView: View {
    private enum Metrics {
        static let aspectRatio: CGFloat = 1.586
        static let cornerRadius: CGFloat = 24
        static let edgeDepth: CGFloat = 8
    }

    var specs = CreditCard3DSpecs()

    @GestureState private var dragTranslation: CGSize = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var tiltX: Double {
        guard !reduceMotion else { return 0 }
        return max(-specs.maxTilt, min(specs.maxTilt, -Double(dragTranslation.height) / 12))
    }

    private var tiltY: Double {
        guard !reduceMotion else { return 0 }
        return max(-specs.maxTilt, min(specs.maxTilt, Double(dragTranslation.width) / 12))
    }

    var body: some View {
        GeometryReader { proxy in
            let width = max(0, min(proxy.size.width - Theme.Spacing.xxl, 520))
            let height = width / Metrics.aspectRatio

            ZStack {
                card(width: width, height: height)
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
                        reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.78),
                        value: dragTranslation
                    )
                    .gesture(tiltGesture)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Purple credit card with an AI glow")
        .accessibilityHint(
            reduceMotion
                ? "Three-dimensional motion is disabled by Reduce Motion"
                : "Drag to tilt the card in three dimensions"
        )
    }

    private func card(width: CGFloat, height: CGFloat) -> some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let phase = reduceMotion
                ? 0.0
                : time.truncatingRemainder(dividingBy: specs.strokePeriod) / specs.strokePeriod
            let angle = phase * 360

            ZStack {
                cardEdge
                    .offset(y: Metrics.edgeDepth)

                cardFace

                aiAura(angle: angle)

                snakeStroke(angle: angle)

                particleTrail(size: CGSize(width: width, height: height), phase: phase)
            }
            .frame(width: width, height: height)
            .contentShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous))
            .shadow(color: Color.black.opacity(0.12), radius: 6, y: 4)
            .shadow(color: Aurora.AI.stops[0].opacity(0.18), radius: 28, y: 18)
        }
    }

    private var cardFace: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)

        return ZStack {
            shape.fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.02, blue: 0.18),
                        Color(red: 0.16, green: 0.05, blue: 0.31),
                        Color(red: 0.10, green: 0.02, blue: 0.22),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            shape.fill(
                RadialGradient(
                    colors: [Aurora.AI.stops[1].opacity(0.18), .clear],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 260
                )
            )

            cardDetails
                .padding(Theme.Spacing.xxl)
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color.white.opacity(0.11), lineWidth: 0.7))
    }

    private var cardEdge: some View {
        RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.17, green: 0.06, blue: 0.32),
                        Color(red: 0.04, green: 0.01, blue: 0.10),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }

    private var cardDetails: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                overlappingCircles
            }

            Spacer()

            HStack(spacing: Theme.Spacing.xxl) {
                embossedCapsule(width: 104)
                embossedCapsule(width: 104)
            }

            HStack(spacing: Theme.Spacing.xxs) {
                ForEach(0..<19, id: \.self) { _ in
                    embossedDot
                }
            }
            .padding(.top, Theme.Spacing.lg)

            Text("CHRISTOPHER WALLACE")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .tracking(3)
                .foregroundStyle(Color.white.opacity(0.08))
                .shadow(color: .black.opacity(0.85), radius: 1, x: 0, y: 1)
                .padding(.top, Theme.Spacing.lg)
        }
    }

    private var overlappingCircles: some View {
        HStack(spacing: -Theme.Spacing.md) {
            embossedCircle
            embossedCircle
        }
    }

    private var embossedCircle: some View {
        Circle()
            .fill(Color.black.opacity(0.05))
            .overlay(Circle().stroke(Color.black.opacity(0.64), lineWidth: 1))
            .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 0.5).offset(y: -0.5))
            .frame(width: 48, height: 48)
    }

    private func embossedCapsule(width: CGFloat) -> some View {
        Capsule()
            .fill(Color.black.opacity(0.12))
            .overlay(Capsule().stroke(Color.black.opacity(0.55), lineWidth: 1))
            .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 0.5).offset(y: -0.5))
            .frame(width: width, height: 11)
    }

    private var embossedDot: some View {
        Circle()
            .fill(Color.black.opacity(0.12))
            .overlay(Circle().stroke(Color.black.opacity(0.58), lineWidth: 0.8))
            .frame(width: 10, height: 10)
    }

    private func aiAura(angle: Double) -> some View {
        RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
            .fill(
                AngularGradient(
                    gradient: Gradient(colors: Aurora.AI.stops + [Aurora.AI.stops[0]]),
                    center: .center,
                    angle: .degrees(angle)
                )
            )
            .blur(radius: 10)
            .opacity(specs.auraOpacity)
            .allowsHitTesting(false)
    }

    private func snakeStroke(angle: Double) -> some View {
        RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
            .strokeBorder(
                AngularGradient(
                    gradient: Gradient(stops: [
                        .init(color: .white, location: 0.00),
                        .init(color: Aurora.AI.stops[2], location: 0.05),
                        .init(color: Aurora.AI.stops[1], location: 0.14),
                        .init(color: Aurora.AI.stops[1].opacity(0), location: 0.30),
                        .init(color: .clear, location: 1.00),
                    ]),
                    center: .center,
                    angle: .degrees(angle)
                ),
                lineWidth: CGFloat(specs.strokeWidth)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
            )
            .allowsHitTesting(false)
    }

    private func particleTrail(size: CGSize, phase: Double) -> some View {
        let particleCount = max(2, Int(specs.particleCount.rounded()))
        let particleDistance = CGFloat(specs.particleDistance)

        Canvas { context, _ in
            for index in 0..<particleCount {
                let progress = Double(index) / Double(particleCount - 1)
                let trailPhase = wrapped(phase - progress * specs.particleTrail)
                let rim = roundedRectanglePoint(
                    phase: trailPhase,
                    size: size,
                    cornerRadius: Metrics.cornerRadius
                )
                let flutter = sin(Double(index * 17) + phase * .pi * 8)
                let radialOffset = CGFloat(flutter) * particleDistance * 0.7
                let point = CGPoint(
                    x: rim.point.x + rim.normal.dx * (particleDistance + radialOffset),
                    y: rim.point.y + rim.normal.dy * (particleDistance + radialOffset)
                )
                let radius = CGFloat(1.2 + (1 - progress) * 2.2)
                let opacity = pow(1 - progress, 1.5) * (0.55 + 0.45 * abs(flutter))
                let color = particleColor(progress: progress).opacity(opacity)
                let rect = CGRect(
                    x: point.x - radius,
                    y: point.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )

                context.drawLayer { glow in
                    glow.addFilter(.blur(radius: radius * 1.8))
                    glow.fill(Path(ellipseIn: rect.insetBy(dx: -radius, dy: -radius)), with: .color(color))
                }
                context.fill(Path(ellipseIn: rect), with: .color(color))
            }
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }

    private func particleColor(progress: Double) -> Color {
        switch progress {
        case ..<0.18: return .white
        case ..<0.55: return Aurora.AI.stops[2]
        default: return Aurora.AI.stops[1]
        }
    }

    private func wrapped(_ value: Double) -> Double {
        let remainder = value.truncatingRemainder(dividingBy: 1)
        return remainder >= 0 ? remainder : remainder + 1
    }

    private func roundedRectanglePoint(
        phase: Double,
        size: CGSize,
        cornerRadius: CGFloat
    ) -> (point: CGPoint, normal: CGVector) {
        let width = size.width
        let height = size.height
        let radius = min(cornerRadius, min(width, height) / 2)
        let horizontal = width - 2 * radius
        let vertical = height - 2 * radius
        let arc = .pi * radius / 2
        let perimeter = 2 * horizontal + 2 * vertical + 4 * arc
        var distance = CGFloat(phase) * perimeter

        func line(
            length: CGFloat,
            start: CGPoint,
            direction: CGVector,
            normal: CGVector
        ) -> (CGPoint, CGVector)? {
            guard distance <= length else {
                distance -= length
                return nil
            }
            return (
                CGPoint(x: start.x + direction.dx * distance, y: start.y + direction.dy * distance),
                normal
            )
        }

        func corner(
            center: CGPoint,
            startAngle: CGFloat
        ) -> (CGPoint, CGVector)? {
            guard distance <= arc else {
                distance -= arc
                return nil
            }
            let angle = startAngle + distance / radius
            let normal = CGVector(dx: cos(angle), dy: sin(angle))
            return (
                CGPoint(x: center.x + normal.dx * radius, y: center.y + normal.dy * radius),
                normal
            )
        }

        if let result = line(
            length: horizontal,
            start: CGPoint(x: radius, y: 0),
            direction: CGVector(dx: 1, dy: 0),
            normal: CGVector(dx: 0, dy: -1)
        ) { return result }
        if let result = corner(
            center: CGPoint(x: width - radius, y: radius),
            startAngle: -.pi / 2
        ) { return result }
        if let result = line(
            length: vertical,
            start: CGPoint(x: width, y: radius),
            direction: CGVector(dx: 0, dy: 1),
            normal: CGVector(dx: 1, dy: 0)
        ) { return result }
        if let result = corner(
            center: CGPoint(x: width - radius, y: height - radius),
            startAngle: 0
        ) { return result }
        if let result = line(
            length: horizontal,
            start: CGPoint(x: width - radius, y: height),
            direction: CGVector(dx: -1, dy: 0),
            normal: CGVector(dx: 0, dy: 1)
        ) { return result }
        if let result = corner(
            center: CGPoint(x: radius, y: height - radius),
            startAngle: .pi / 2
        ) { return result }
        if let result = line(
            length: vertical,
            start: CGPoint(x: 0, y: height - radius),
            direction: CGVector(dx: 0, dy: -1),
            normal: CGVector(dx: -1, dy: 0)
        ) { return result }
        return corner(center: CGPoint(x: radius, y: radius), startAngle: .pi)
            ?? (CGPoint(x: radius, y: 0), CGVector(dx: 0, dy: -1))
    }

    private var tiltGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .updating($dragTranslation) { value, state, _ in
                state = value.translation
            }
    }
}

#Preview {
    CreditCard3DView()
        .frame(height: 420)
        .background(Color.black.opacity(0.03))
}
