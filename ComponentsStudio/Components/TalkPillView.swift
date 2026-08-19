import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Liquid Glass talk button derived from Glass Pill.
/// Idle: SF Symbol mic + "Talk". Tap morphs the mic into a live waveform
/// (liquidMorph shader). Talk letters keep the per-glyph suck-in.
struct TalkPillView: View {
    let specs: TalkPillSpecs

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isListening = false
    /// Drives the liquid-morph progress (0 idle → 1 listening).
    @State private var morphToggle = false
    /// Flips at the morph midpoint so the shader hides the icon swap.
    @State private var showListeningContent = false
    @State private var lettersGone = false
    @State private var compactPill = false
    @State private var waveLive = false
    @State private var waveBirth: CGFloat = 0
    @State private var squash: CGFloat = 1
    @State private var energy: CGFloat = 0
    @State private var isPopping = false
    @State private var morphGeneration = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            talkButton
        }
        .environment(\.colorScheme, .dark)
    }

    private var talkButton: some View {
        Button {
            toggleListening()
        } label: {
            HStack(spacing: compactPill ? 0 : Theme.Spacing.xs) {
                morphingIcon
                talkLabel
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)
            .background { glassCapsule }
            .overlay { energyFlash }
            .scaleEffect(x: 1 + (1 - squash) * 0.12, y: squash)
            .scaleEffect(displayScale * (1 + energy * 0.03))
            .contentShape(Capsule())
        }
        .buttonStyle(GlassPillPressStyle(pressScale: specs.pressScale))
        .accessibilityLabel(isListening ? "Stop listening" : "Talk")
        .accessibilityHint(
            isListening
                ? "Stops voice capture"
                : "Starts voice capture and morphs the microphone into a sound wave"
        )
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(isListening ? "Listening" : "Idle")
    }

    private var displayScale: CGFloat {
        let base = specs.restScale
        return isPopping ? base * (1.0 + specs.pressPop) : base
    }

    private var glassCapsule: some View {
        Capsule()
            .fill(.clear)
            .glassEffect(
                specs.tintOpacity > 0.01
                    ? .regular.interactive().tint(.white.opacity(specs.tintOpacity))
                    : .regular.interactive(),
                in: Capsule()
            )
            .opacity(specs.glassOpacity)
    }

    private var energyFlash: some View {
        Capsule()
            .fill(
                RadialGradient(
                    colors: [
                        .white.opacity(0.22 * energy),
                        .white.opacity(0.05 * energy),
                        .clear
                    ],
                    center: .leading,
                    startRadius: 2,
                    endRadius: 80
                )
            )
            .allowsHitTesting(false)
    }

    private var morphingIcon: some View {
        ZStack {
            if showListeningContent {
                VoiceWaveform(
                    isLive: waveLive,
                    birth: waveBirth,
                    amplitude: specs.waveAmplitude,
                    speed: specs.waveSpeed,
                    color: .white
                )
            } else {
                Image(systemName: "mic")
                    .font(.system(size: TalkPillMetrics.iconSize, weight: .semibold))
            }
        }
        .foregroundStyle(.white)
        .frame(width: TalkPillMetrics.iconSlot, height: TalkPillMetrics.iconSlot)
        .liquidMorphingTransition(
            progress: morphToggle ? 1 : 0,
            blurRadius: reduceMotion ? 0 : specs.morphBlur,
            intensity: reduceMotion ? 0 : 1.2,
            chroma: reduceMotion ? 0 : 1.05
        )
        .zIndex(1)
    }

    private var talkLabel: some View {
        TalkLetters(collapsing: lettersGone, reduceMotion: reduceMotion)
            .frame(width: compactPill ? 0 : TalkPillMetrics.talkWidth, alignment: .leading)
            .frame(height: TalkPillMetrics.iconSlot)
            .opacity(compactPill ? 0 : 1)
            .accessibilityHidden(true)
    }

    private func toggleListening() {
        let destination = !isListening
        isListening = destination
        morphGeneration += 1
        let generation = morphGeneration
        haptic(starting: destination)
        triggerPop()

        if reduceMotion {
            morphToggle = destination
            showListeningContent = destination
            lettersGone = destination
            compactPill = destination
            waveBirth = destination ? 1 : 0
            waveLive = destination
            squash = 1
            energy = 0
            return
        }

        flashEnergy()
        anticipate()

        if destination {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.82).delay(0.08)) {
                lettersGone = true
            }
            withAnimation(TalkPillMetrics.morphAnimation) {
                morphToggle = true
            }
            withAnimation(.spring(response: 0.52, dampingFraction: 0.86).delay(0.48)) {
                compactPill = true
            }
        } else {
            waveLive = false
            withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
                waveBirth = 0
                compactPill = false
                lettersGone = false
            }
            withAnimation(TalkPillMetrics.morphAnimation) {
                morphToggle = false
            }
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(TalkPillMetrics.swapMs))
            guard generation == morphGeneration else { return }
            hapticSnap()
            showListeningContent = destination
            if destination {
                waveBirth = 0
                withAnimation(.spring(response: 0.42, dampingFraction: 0.52)) {
                    waveBirth = 1
                }
                try? await Task.sleep(for: .milliseconds(220))
                guard generation == morphGeneration else { return }
                waveLive = true
            }
        }
    }

    private func anticipate() {
        withAnimation(.easeOut(duration: 0.06)) {
            squash = 0.86
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(60))
            withAnimation(.interpolatingSpring(duration: 0.24)) {
                squash = 1
            }
        }
    }

    private func flashEnergy() {
        withAnimation(.easeOut(duration: 0.1)) {
            energy = 1
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(90))
            withAnimation(.easeIn(duration: 0.4)) {
                energy = 0
            }
        }
    }

    private func triggerPop() {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.52)) {
            isPopping = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(.spring(response: 0.36, dampingFraction: 0.72)) {
                isPopping = false
            }
        }
    }

    private func haptic(starting: Bool) {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: starting ? .medium : .light).impactOccurred()
        #endif
    }

    private func hapticSnap() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        #endif
    }
}

private enum TalkPillMetrics {
    static let iconSize: CGFloat = 18
    static let iconSlot: CGFloat = 22
    static let talkWidth: CGFloat = 36
    static let barCount = 5
    static let barWidth: CGFloat = 2.5
    static let barSpacing: CGFloat = 2
    static let maxBarHeight: CGFloat = 18
    static let swapMs: UInt64 = 470
    static let morphAnimation: Animation = .interpolatingSpring(duration: 0.94, bounce: 0.04)
    static let restHeights: [CGFloat] = [0.38, 0.72, 0.50, 0.92, 0.42]
    static let frequencies: [Double] = [1.7, 2.35, 1.15, 2.85, 1.95]
    static let phases: [Double] = [0.0, 1.1, 2.4, 0.6, 3.2]
}

// MARK: - Waveform

/// Five capsules that sit still as a morph target, then pop into voice motion.
private struct VoiceWaveform: View {
    var isLive: Bool
    var birth: CGFloat
    var amplitude: Double
    var speed: Double
    var color: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: isLive ? 1.0 / 60.0 : nil, paused: !isLive)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate * speed
            HStack(spacing: TalkPillMetrics.barSpacing) {
                ForEach(0..<TalkPillMetrics.barCount, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(color)
                        .frame(width: TalkPillMetrics.barWidth, height: barHeight(index: index, time: t))
                        .scaleEffect(y: birth > 0 ? 1 : 0.12, anchor: .center)
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.5)
                                .delay(Double(index) * 0.038),
                            value: birth
                        )
                }
            }
        }
        .frame(width: TalkPillMetrics.iconSlot, height: TalkPillMetrics.iconSlot)
    }

    private func barHeight(index: Int, time: Double) -> CGFloat {
        let rest = TalkPillMetrics.restHeights[index]
        let minHeight = TalkPillMetrics.barWidth
        let restHeight = max(minHeight, TalkPillMetrics.maxBarHeight * rest)
        guard isLive else { return restHeight }

        let freq = TalkPillMetrics.frequencies[index]
        let phase = TalkPillMetrics.phases[index]
        let voice = sin(time * freq + phase)
        let overlay = sin(time * freq * 1.63 + phase * 0.55)
        let envelope = 0.5 + 0.5 * (0.72 * voice + 0.28 * overlay)
        let travel = rest + (envelope - rest) * amplitude
        return max(minHeight, TalkPillMetrics.maxBarHeight * travel)
    }
}

/// Per-letter suck-in as the opened outline takes over the pill.
private struct TalkLetters: View {
    var collapsing: Bool
    var reduceMotion: Bool

    private let chars: [Character] = ["T", "a", "l", "k"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(chars.enumerated()), id: \.offset) { index, char in
                Text(String(char))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .rotationEffect(
                        .degrees(collapsing ? Double(index) * 10 - 12 : 0),
                        anchor: .bottom
                    )
                    .offset(
                        x: collapsing ? -12 - CGFloat(index) * 5 : 0,
                        y: collapsing ? (index.isMultiple(of: 2) ? -4 : 5) : 0
                    )
                    .scaleEffect(collapsing ? 0.32 : 1, anchor: .leading)
                    .blur(radius: reduceMotion ? 0 : (collapsing ? 6 : 0))
                    .opacity(collapsing ? 0 : 1)
                    .animation(letterAnimation(index: index), value: collapsing)
            }
        }
    }

    private func letterAnimation(index: Int) -> Animation {
        if reduceMotion { return .easeOut(duration: 0.12) }
        return .spring(response: 0.5, dampingFraction: 0.78)
            .delay(Double(index) * 0.04)
    }
}

#Preview("Talk Pill") {
    TalkPillView(
        specs: TalkPillSpecs(
            ComponentSpecState(defaults: StudioItem.talkPill.specDefaults),
            sheet: StudioItem.talkPill.specSheet!
        )
    )
}
