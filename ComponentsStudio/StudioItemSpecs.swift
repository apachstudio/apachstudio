import Foundation

// MARK: - Per-component typed specs
//
// Each struct reads live values from `ComponentSpecState` using the
// stable string keys declared in `StudioItem.specSheet`.

struct SearchBoxSpecs: Equatable {
    var focusResponse: Double
    var focusDamping: Double
    var focusScale: Double
    var auraPeriodFocused: Double
    var auraPeriodRest: Double
    var snakeWidthFocused: Double
    var snakeWidthRest: Double

    @MainActor
    init(_ state: ComponentSpecState, sheet: ComponentSpecSheet) {
        focusResponse = sheet.value("focusResponse", in: state)
        focusDamping = sheet.value("focusDamping", in: state)
        focusScale = sheet.value("focusScale", in: state)
        auraPeriodFocused = sheet.value("auraPeriodFocused", in: state)
        auraPeriodRest = sheet.value("auraPeriodRest", in: state)
        snakeWidthFocused = sheet.value("snakeWidthFocused", in: state)
        snakeWidthRest = sheet.value("snakeWidthRest", in: state)
    }
}

struct CreditCard3DSpecs: Equatable {
    var maxTilt: Double
    var perspective: Double
    var strokePeriod: Double
    var strokeWidth: Double
    var auraOpacity: Double
    var particleCount: Double
    var particleDistance: Double
    var particleTrail: Double

    init(
        maxTilt: Double = 12,
        perspective: Double = 0.55,
        strokePeriod: Double = 4.2,
        strokeWidth: Double = 0.9,
        auraOpacity: Double = 0.13,
        particleCount: Double = 24,
        particleDistance: Double = 7,
        particleTrail: Double = 0.22
    ) {
        self.maxTilt = maxTilt
        self.perspective = perspective
        self.strokePeriod = strokePeriod
        self.strokeWidth = strokeWidth
        self.auraOpacity = auraOpacity
        self.particleCount = particleCount
        self.particleDistance = particleDistance
        self.particleTrail = particleTrail
    }

    @MainActor
    init(_ state: ComponentSpecState, sheet: ComponentSpecSheet) {
        maxTilt = sheet.value("maxTilt", in: state)
        perspective = sheet.value("perspective", in: state)
        strokePeriod = sheet.value("strokePeriod", in: state)
        strokeWidth = sheet.value("strokeWidth", in: state)
        auraOpacity = sheet.value("auraOpacity", in: state)
        particleCount = sheet.value("particleCount", in: state)
        particleDistance = sheet.value("particleDistance", in: state)
        particleTrail = sheet.value("particleTrail", in: state)
    }
}

struct AnimatedCreditCardSpecs: Equatable {
    var strokePeriod: Double
    var strokeWidth: Double
    var auraBlurRadius: Double
    var auraOpacity: Double
    var particleCount: Double
    var particleDuration: Double
    var minimumSpeed: Double
    var maximumSpeed: Double
    var gravity: Double
    var particleSpreadDegrees: Double
    var maximumOpacity: Double

    init(
        strokePeriod: Double = 4.2,
        strokeWidth: Double = 0.9,
        auraBlurRadius: Double = 10,
        auraOpacity: Double = 0.13,
        particleCount: Double = 24,
        particleDuration: Double = 2,
        minimumSpeed: Double = 40,
        maximumSpeed: Double = 80,
        gravity: Double = 147.15,
        particleSpreadDegrees: Double = 32.4,
        maximumOpacity: Double = 0.48
    ) {
        self.strokePeriod = strokePeriod
        self.strokeWidth = strokeWidth
        self.auraBlurRadius = auraBlurRadius
        self.auraOpacity = auraOpacity
        self.particleCount = particleCount
        self.particleDuration = particleDuration
        self.minimumSpeed = minimumSpeed
        self.maximumSpeed = maximumSpeed
        self.gravity = gravity
        self.particleSpreadDegrees = particleSpreadDegrees
        self.maximumOpacity = maximumOpacity
    }

    @MainActor
    init(_ state: ComponentSpecState, sheet: ComponentSpecSheet) {
        strokePeriod = sheet.value("strokePeriod", in: state)
        strokeWidth = sheet.value("strokeWidth", in: state)
        auraBlurRadius = sheet.value("auraBlurRadius", in: state)
        auraOpacity = sheet.value("auraOpacity", in: state)
        particleCount = sheet.value("particleCount", in: state)
        particleDuration = sheet.value("particleDuration", in: state)
        minimumSpeed = sheet.value("minimumSpeed", in: state)
        maximumSpeed = sheet.value("maximumSpeed", in: state)
        gravity = sheet.value("gravity", in: state)
        particleSpreadDegrees = sheet.value("particleSpreadDegrees", in: state)
        maximumOpacity = sheet.value("maximumOpacity", in: state)
    }
}

struct SearchModalSpecs: Equatable {
    var blurAmount: Double
    var blurRevealDuration: Double
    var wordStagger: Double
    var cardStagger: Double
    var cardRevealDuration: Double
    var holdDuration: Double

    @MainActor
    init(_ state: ComponentSpecState, sheet: ComponentSpecSheet) {
        blurAmount = sheet.value("blurAmount", in: state)
        blurRevealDuration = sheet.value("blurRevealDuration", in: state)
        wordStagger = sheet.value("wordStagger", in: state)
        cardStagger = sheet.value("cardStagger", in: state)
        cardRevealDuration = sheet.value("cardRevealDuration", in: state)
        holdDuration = sheet.value("holdDuration", in: state)
    }
}

struct PlaceDeckSpecs: Equatable {
    var edgeScale: Double
    var edgeOpacity: Double
    var maxEdgeBlur: Double
    var parallaxAmount: Double
    var settleScale: Double
    var settleDuration: Double

    @MainActor
    init(_ state: ComponentSpecState, sheet: ComponentSpecSheet) {
        edgeScale = sheet.value("edgeScale", in: state)
        edgeOpacity = sheet.value("edgeOpacity", in: state)
        maxEdgeBlur = sheet.value("maxEdgeBlur", in: state)
        parallaxAmount = sheet.value("parallaxAmount", in: state)
        settleScale = sheet.value("settleScale", in: state)
        settleDuration = sheet.value("settleDuration", in: state)
    }
}

struct SampleGlassPillSpecs: Equatable {
    var glassOpacity: Double
    var tintOpacity: Double
    var restScale: Double
    var pressPop: Double
    var pressScale: Double

    @MainActor
    init(_ state: ComponentSpecState, sheet: ComponentSpecSheet) {
        glassOpacity = sheet.value("glassOpacity", in: state)
        tintOpacity = sheet.value("tintOpacity", in: state)
        restScale = sheet.value("restScale", in: state)
        pressPop = sheet.value("pressPop", in: state)
        pressScale = sheet.value("pressScale", in: state)
    }
}

struct TalkPillSpecs: Equatable {
    var glassOpacity: Double
    var tintOpacity: Double
    var restScale: Double
    var pressPop: Double
    var pressScale: Double
    var morphBlur: Double
    var waveSpeed: Double
    var waveAmplitude: Double

    @MainActor
    init(_ state: ComponentSpecState, sheet: ComponentSpecSheet) {
        glassOpacity = sheet.value("glassOpacity", in: state)
        tintOpacity = sheet.value("tintOpacity", in: state)
        restScale = sheet.value("restScale", in: state)
        pressPop = sheet.value("pressPop", in: state)
        pressScale = sheet.value("pressScale", in: state)
        morphBlur = sheet.value("morphBlur", in: state)
        waveSpeed = sheet.value("waveSpeed", in: state)
        waveAmplitude = sheet.value("waveAmplitude", in: state)
    }
}

struct PhotoRippleSpecs: Equatable {
    var amplitude: Double
    var frequency: Double
    var decay: Double
    var speed: Double
    var highlight: Double
    var duration: Double

    @MainActor
    init(_ state: ComponentSpecState, sheet: ComponentSpecSheet) {
        amplitude = sheet.value("amplitude", in: state)
        frequency = sheet.value("frequency", in: state)
        decay = sheet.value("decay", in: state)
        speed = sheet.value("speed", in: state)
        highlight = sheet.value("highlight", in: state)
        duration = sheet.value("duration", in: state)
    }
}

struct PhotoRipple2Specs: Equatable {
    var speed: Double
    var bandWidth: Double
    var maxRadius: Double
    var refract: Double
    var glint: Double
    var falloff: Double
    var swirl: Double
    var displacement: Double
    var life: Double
    var emitSpacing: Double
    var chromatic: Double

    @MainActor
    init(_ state: ComponentSpecState, sheet: ComponentSpecSheet) {
        speed = sheet.value("speed", in: state)
        bandWidth = sheet.value("bandWidth", in: state)
        maxRadius = sheet.value("maxRadius", in: state)
        refract = sheet.value("refract", in: state)
        glint = sheet.value("glint", in: state)
        falloff = sheet.value("falloff", in: state)
        swirl = sheet.value("swirl", in: state)
        displacement = sheet.value("displacement", in: state)
        life = sheet.value("life", in: state)
        emitSpacing = sheet.value("emitSpacing", in: state)
        chromatic = sheet.value("chromatic", in: state)
    }
}

// Refractive Sphere is a refractive-glass lens over a black card with a
// centered sphere image; reuses the exact same knob set as Refractive Photo.
struct BubbleTextRippleSpecs: Equatable {
    var refraction: Double
    var falloff: Double
    var swirl: Double
    var glassRadius: Double
    var chromatic: Double

    @MainActor
    init(_ state: ComponentSpecState, sheet: ComponentSpecSheet) {
        refraction = sheet.value("refraction", in: state)
        falloff = sheet.value("falloff", in: state)
        swirl = sheet.value("swirl", in: state)
        glassRadius = sheet.value("glassRadius", in: state)
        chromatic = sheet.value("chromatic", in: state)
    }
}

struct DottedBackgroundSpecs: Equatable {
    var mode: Double
    var gridDensity: Double
    var influenceRadius: Double
    var maxDisplacement: Double
    var bgR: Double
    var bgG: Double
    var bgB: Double
    var bg2R: Double
    var bg2G: Double
    var bg2B: Double
    var dotR: Double
    var dotG: Double
    var dotB: Double
    var accentR: Double
    var accentG: Double
    var accentB: Double
    var glowR: Double
    var glowG: Double
    var glowB: Double
    var glowAmount: Double
    var accentMix: Double
    var dotSizeMin: Double
    var dotSizeMax: Double
    var spotR: Double
    var spotG: Double
    var spotB: Double
    var fisheyeAmount: Double
    var dotShape: Double

    @MainActor
    init(_ state: ComponentSpecState, sheet: ComponentSpecSheet) {
        mode = sheet.value("mode", in: state)
        gridDensity = sheet.value("gridDensity", in: state)
        influenceRadius = sheet.value("influenceRadius", in: state)
        maxDisplacement = sheet.value("maxDisplacement", in: state)
        bgR = sheet.value("bgR", in: state)
        bgG = sheet.value("bgG", in: state)
        bgB = sheet.value("bgB", in: state)
        bg2R = sheet.value("bg2R", in: state)
        bg2G = sheet.value("bg2G", in: state)
        bg2B = sheet.value("bg2B", in: state)
        dotR = sheet.value("dotR", in: state)
        dotG = sheet.value("dotG", in: state)
        dotB = sheet.value("dotB", in: state)
        accentR = sheet.value("accentR", in: state)
        accentG = sheet.value("accentG", in: state)
        accentB = sheet.value("accentB", in: state)
        glowR = sheet.value("glowR", in: state)
        glowG = sheet.value("glowG", in: state)
        glowB = sheet.value("glowB", in: state)
        glowAmount = sheet.value("glowAmount", in: state)
        accentMix = sheet.value("accentMix", in: state)
        dotSizeMin = sheet.value("dotSizeMin", in: state)
        dotSizeMax = sheet.value("dotSizeMax", in: state)
        spotR = sheet.value("spotR", in: state)
        spotG = sheet.value("spotG", in: state)
        spotB = sheet.value("spotB", in: state)
        fisheyeAmount = sheet.value("fisheyeAmount", in: state)
        dotShape = sheet.value("dotShape", in: state)
    }
}

struct RefractiveGlassSpecs: Equatable {
    var refraction: Double
    var falloff: Double
    var swirl: Double
    var glassRadius: Double
    var chromatic: Double

    @MainActor
    init(_ state: ComponentSpecState, sheet: ComponentSpecSheet) {
        refraction = sheet.value("refraction", in: state)
        falloff = sheet.value("falloff", in: state)
        swirl = sheet.value("swirl", in: state)
        glassRadius = sheet.value("glassRadius", in: state)
        chromatic = sheet.value("chromatic", in: state)
    }
}

struct SDFLiquidSpecs: Equatable {
    var smoothness: Double
    var glowAmount: Double
    var motionSpeed: Double
    var springStrength: Double
    var damping: Double

    @MainActor
    init(_ state: ComponentSpecState, sheet: ComponentSpecSheet) {
        smoothness = sheet.value("smoothness", in: state)
        glowAmount = sheet.value("glowAmount", in: state)
        motionSpeed = sheet.value("motionSpeed", in: state)
        springStrength = sheet.value("springStrength", in: state)
        damping = sheet.value("damping", in: state)
    }
}

// Flame in Glass — the Glass Pill capsule with one of two fills inside.
// `fill` < 0.5 → flame gradient; >= 0.5 → SDF liquid blobs (flame palette).
// The Merge/Glow/Drift knobs tune the liquid-blobs option.
struct FlameInGlassSpecs: Equatable {
    var fill: Double
    var smoothness: Double
    var glowAmount: Double
    var motionSpeed: Double

    @MainActor
    init(_ state: ComponentSpecState, sheet: ComponentSpecSheet) {
        fill = sheet.value("fill", in: state)
        smoothness = sheet.value("smoothness", in: state)
        glowAmount = sheet.value("glowAmount", in: state)
        motionSpeed = sheet.value("motionSpeed", in: state)
    }
}

// SDF Flame — standalone flame component knobs.
struct FlameSpecs: Equatable {
    var height: Double
    var width: Double
    var flicker: Double
    var speed: Double
    var softness: Double
    var glow: Double

    @MainActor
    init(_ state: ComponentSpecState, sheet: ComponentSpecSheet) {
        height = sheet.value("flameHeight", in: state)
        width = sheet.value("flameWidth", in: state)
        flicker = sheet.value("flameFlicker", in: state)
        speed = sheet.value("flameSpeed", in: state)
        softness = sheet.value("flameSoftness", in: state)
        glow = sheet.value("flameGlow", in: state)
    }
}

struct NeumorphicDigitSpecs: Equatable {
    var iconSize: Double
    var revealDelay: Double
    var motionResponse: Double
    var motionDamping: Double
    var surfaceTone: Double
    var shadowOffsetX: Double
    var shadowOffsetY: Double
    var shadowRadius: Double
    var shadowOpacity: Double
    var iconOpacity: Double
    var iconColorR: Double
    var iconColorG: Double
    var iconColorB: Double

    @MainActor
    init(_ state: ComponentSpecState, sheet: ComponentSpecSheet) {
        iconSize = sheet.value("iconSize", in: state)
        revealDelay = sheet.value("revealDelay", in: state)
        motionResponse = sheet.value("motionResponse", in: state)
        motionDamping = sheet.value("motionDamping", in: state)
        surfaceTone = sheet.value("surfaceTone", in: state)
        shadowOffsetX = sheet.value("shadowOffsetX", in: state)
        shadowOffsetY = sheet.value("shadowOffsetY", in: state)
        shadowRadius = sheet.value("shadowRadius", in: state)
        shadowOpacity = sheet.value("shadowOpacity", in: state)
        iconOpacity = sheet.value("iconOpacity", in: state)
        iconColorR = sheet.value("iconColorR", in: state)
        iconColorG = sheet.value("iconColorG", in: state)
        iconColorB = sheet.value("iconColorB", in: state)
    }
}

// Neumorphic Pills — a "+" pill that pops in↔out (morphing + → ×) on tap.
struct NeumorphicPillsSpecs: Equatable {
    var iconSize: Double
    var surfaceTone: Double
    var shadowOffset: Double
    var shadowRadius: Double
    /// Pill bevel shadow strength, pressed-in vs popped-out.
    var pillShadowIn: Double
    var pillShadowOut: Double
    /// Icon emboss shadow strength, pressed-in vs popped-out.
    var iconShadowIn: Double
    var iconShadowOut: Double
    /// In↔out transition spring.
    var motionResponse: Double
    var motionDamping: Double
    /// When true, uses ease-in-out (slow → fast → slow) instead of spring.
    var motionEase: Bool

    @MainActor
    init(_ state: ComponentSpecState, sheet: ComponentSpecSheet) {
        iconSize = sheet.value("iconSize", in: state)
        surfaceTone = sheet.value("surfaceTone", in: state)
        shadowOffset = sheet.value("shadowOffset", in: state)
        shadowRadius = sheet.value("shadowRadius", in: state)
        pillShadowIn = sheet.value("pillShadowIn", in: state)
        pillShadowOut = sheet.value("pillShadowOut", in: state)
        iconShadowIn = sheet.value("iconShadowIn", in: state)
        iconShadowOut = sheet.value("iconShadowOut", in: state)
        motionResponse = sheet.value("motionResponse", in: state)
        motionDamping = sheet.value("motionDamping", in: state)
        motionEase = sheet.value("motionEase", in: state) >= 0.5
    }
}

// MARK: - Registry

extension StudioItem {
    var specSheet: ComponentSpecSheet? {
        Self.allSpecSheets[self]
    }

    var specDefaults: [String: Double] {
        specSheet?.defaults ?? [:]
    }

    /// Built-in default preset — the original tuned component. User-pinned
    /// variants are managed at runtime in `UnifiedStudioStage`.
    var presets: [StudioComponentPreset] {
        switch self {
        case .searchPillRest: return Self.searchPillPresets
        case .blurFocusLoading: return Self.blurFocusPresets
        case .bubbleCard: return []
        case .creditCard3D: return Self.creditCard3DPresets
        case .animatedCreditCard: return Self.animatedCreditCardPresets
        case .verticalCardDeck: return Self.deckPresets
        case .sampleGlassPill: return Self.glassPillPresets
        case .talkPill: return Self.talkPillPresets
        case .photoRipple: return Self.photoRipplePresets
        case .photoRipple2: return Self.photoRipple2Presets
        case .bubbleTextRipple: return Self.bubbleTextRipplePresets
        case .refractiveText: return Self.refractiveTextPresets
        case .dottedBackground: return Self.dottedBackgroundPresets
        case .neumorphicDigit: return Self.neumorphicDigitPresets
        case .neumorphicPills: return Self.neumorphicPillsPresets
        case .sdfLiquid: return Self.sdfLiquidPresets
        case .flameInGlass: return Self.flameInGlassPresets
        case .flame: return Self.flamePresets
        }
    }

    /// Whether this item uses the shared `UnifiedStudioStage` chrome.
    var usesUnifiedStage: Bool {
        switch self {
        case .bubbleCard: return false
        default: return true
        }
    }

    /// Dark canvas stages need white FAB glyphs for contrast.
    var prefersDarkStageChrome: Bool {
        switch self {
        case .sampleGlassPill, .talkPill, .flame: return true
        default: return false
        }
    }

    @MainActor
    func swiftCodeSnippet(state: ComponentSpecState, presetLabel: String) -> String {
        guard let sheet = specSheet else { return "// No spec sheet" }
        switch self {
        case .searchPillRest:
            let s = SearchBoxSpecs(state, sheet: sheet)
            return """
            // Generated by Component Studio · preset: \(presetLabel)
            // SearchBoxView motion specs

            let focusAnimation: Animation = .spring(response: \(fmt(s.focusResponse)), dampingFraction: \(fmt(s.focusDamping)))
            let focusScale: CGFloat = \(fmt(s.focusScale))
            let auraPeriodFocused: Double = \(fmt(s.auraPeriodFocused))
            let auraPeriodRest: Double = \(fmt(s.auraPeriodRest))
            let snakeWidthFocused: CGFloat = \(fmt(s.snakeWidthFocused))
            let snakeWidthRest: CGFloat = \(fmt(s.snakeWidthRest))
            """

        case .blurFocusLoading:
            let s = SearchModalSpecs(state, sheet: sheet)
            return """
            // Generated by Component Studio · preset: \(presetLabel)
            // SearchModalView blur-focus loading specs

            let blurAmount: CGFloat = \(fmt(s.blurAmount))
            let blurRevealDuration: Double = \(fmt(s.blurRevealDuration))
            let wordStagger: Double = \(fmt(s.wordStagger))
            let cardStagger: Double = \(fmt(s.cardStagger))
            let cardRevealDuration: Double = \(fmt(s.cardRevealDuration))
            let holdDuration: Double = \(fmt(s.holdDuration))
            """

        case .verticalCardDeck:
            let s = PlaceDeckSpecs(state, sheet: sheet)
            return """
            // Generated by Component Studio · preset: \(presetLabel)
            // PlaceDeckView scroll / settle specs

            let edgeScale: CGFloat = \(fmt(s.edgeScale))
            let edgeOpacity: Double = \(fmt(s.edgeOpacity))
            let maxEdgeBlur: CGFloat = \(fmt(s.maxEdgeBlur))
            let parallaxAmount: CGFloat = \(fmt(s.parallaxAmount))
            let settleScale: CGFloat = \(fmt(s.settleScale))
            let settleDuration: Double = \(fmt(s.settleDuration))
            """

        case .sampleGlassPill:
            let s = SampleGlassPillSpecs(state, sheet: sheet)
            return """
            // Generated by Component Studio · preset: \(presetLabel)
            // Glass Pill — Liquid Glass + morphing SF Symbol

            let glassOpacity: Double = \(fmt(s.glassOpacity))
            let tintOpacity: Double = \(fmt(s.tintOpacity))
            let restScale: CGFloat = \(fmt(s.restScale))
            let pressPop: CGFloat = \(fmt(s.pressPop))
            let pressScale: CGFloat = \(fmt(s.pressScale))

            // Morphing icon: bag (empty) ↔ gift.fill.
            // Uses MorphingSymbolIcon + alphaThreshold shader.
            """

        case .talkPill:
            let s = TalkPillSpecs(state, sheet: sheet)
            return """
            // Generated by Component Studio · preset: \(presetLabel)
            // Talk Pill — Glass Pill chrome + mic → live waveform morph

            let glassOpacity: Double = \(fmt(s.glassOpacity))
            let tintOpacity: Double = \(fmt(s.tintOpacity))
            let restScale: CGFloat = \(fmt(s.restScale))
            let pressPop: CGFloat = \(fmt(s.pressPop))
            let pressScale: CGFloat = \(fmt(s.pressScale))
            let morphBlur: CGFloat = \(fmt(s.morphBlur))
            let waveSpeed: Double = \(fmt(s.waveSpeed))
            let waveAmplitude: Double = \(fmt(s.waveAmplitude))

            // Mic ↔ 5-bar voice waveform via liquidMorph (mercury melt).
            // Talk letters stagger-suck into the icon; bars overshoot on birth.
            """

        case .photoRipple:
            let s = PhotoRippleSpecs(state, sheet: sheet)
            return """
            // Generated by Component Studio · preset: \(presetLabel)
            // Liquid Photo — Apple WWDC24 ripple (.layerEffect, photo distorts)

            let amplitude: Float = \(fmt(s.amplitude))   // peak pixel displacement
            let frequency: Float = \(fmt(s.frequency))   // number of crests
            let decay: Float = \(fmt(s.decay))           // how fast the wave fades
            let speed: Float = \(fmt(s.speed))           // propagation speed (px/s)
            let highlight: Float = \(fmt(s.highlight))   // white crest brightness
            let duration: Double = \(fmt(s.duration))    // ripple lifetime (s)
            """

        case .photoRipple2:
            let s = PhotoRipple2Specs(state, sheet: sheet)
            return """
            // Generated by Component Studio · preset: \(presetLabel)
            // Photo Ripple — Liquid Glass fusion (WWDC ripple + Baro refraction),
            // stacked .layerEffect on the photo; finger-following drag trail

            let speed: Float = \(fmt(s.speed))             // wavefront expansion (px/s)
            let bandWidth: Float = \(fmt(s.bandWidth))     // glass band width (px)
            let maxRadius: Float = \(fmt(s.maxRadius))     // radius where the ring dies (px)
            let refract: Float = \(fmt(s.refract))         // Baro radial refraction strength
            let glint: Float = \(fmt(s.glint))             // specular rim highlight
            let falloff: Float = \(fmt(s.falloff))         // lens curve: 1 - pow(r, falloff)
            let swirl: Float = \(fmt(s.swirl))             // tangent rotation at crest (rad)
            let displacement: Float = \(fmt(s.displacement)) // WWDC crest displacement (px)
            let life: Double = \(fmt(s.life))              // ring lifetime (s)
            let emitSpacing: Float = \(fmt(s.emitSpacing)) // px between rings while dragging
            let chromatic: Float = \(fmt(s.chromatic))     // chromatic aberration at band edge
            """

        case .bubbleTextRipple:
            let s = BubbleTextRippleSpecs(state, sheet: sheet)
            return """
            // Generated by Component Studio · preset: \(presetLabel)
            // Refractive Sphere — refractive glass lens over a black card
            // with a centered sphere image; same refractiveGlass shader, draggable lens.
            let refraction: Float = \(fmt(s.refraction))       // Snell-style background bend
            let falloff: Float = \(fmt(s.falloff))             // distortion curve: 1 - pow(r, falloff)
            let swirl: Float = \(fmt(s.swirl))                 // rotation at center (radians)
            let glassRadius: Float = \(fmt(s.glassRadius))     // lens radius (px)
            let chromatic: Float = \(fmt(s.chromatic))         // R/B split toward the edge
            """

        case .refractiveText:
            let s = BubbleTextRippleSpecs(state, sheet: sheet)
            return """
            // Generated by Component Studio · preset: \(presetLabel)
            // Refractive Text — ping-pong lens on typography only; photo bg stays flat.

            // Scale Dripdrop so "apach" sits 12pt from the card edges.
            let textSidePadding: CGFloat = 12
            let displayFontSize: CGFloat = {
                let available = cardWidth - textSidePadding * 2
                let reference: CGFloat = 100
                let font = UIFont(name: "Dripdrop-Regular", size: reference)
                    ?? UIFont.systemFont(ofSize: reference, weight: .bold)
                let width = ("apach" as NSString).size(withAttributes: [.font: font]).width
                return width > 0 ? reference * (available / width) : reference
            }()
            let displayFont: Font = AppFont.dripdrop(displayFontSize)

            let refraction: Float = \(fmt(s.refraction))
            let falloff: Float = \(fmt(s.falloff))
            let swirl: Float = \(fmt(s.swirl))
            let glassRadius: Float = \(fmt(s.glassRadius))
            let chromatic: Float = \(fmt(s.chromatic))
            """

        case .dottedBackground:
            let s = DottedBackgroundSpecs(state, sheet: sheet)
            return """
            // Generated by Component Studio · preset: \(presetLabel)
            // DottedBackgroundView specs

            let mode: Float = \(fmt(s.mode))               // 0=glow, 1=attraction, 2=repulsion
            let gridDensity: Float = \(fmt(s.gridDensity))
            let influenceRadius: Float = \(fmt(s.influenceRadius))
            let maxDisplacement: Float = \(fmt(s.maxDisplacement))
            let bgColor = SIMD4<Float>(\(fmt(s.bgR)), \(fmt(s.bgG)), \(fmt(s.bgB)), 0)
            let bgColor2 = SIMD4<Float>(\(fmt(s.bg2R)), \(fmt(s.bg2G)), \(fmt(s.bg2B)), 0)
            let dotColor = SIMD4<Float>(\(fmt(s.dotR)), \(fmt(s.dotG)), \(fmt(s.dotB)), 0)
            let accentColor = SIMD4<Float>(\(fmt(s.accentR)), \(fmt(s.accentG)), \(fmt(s.accentB)), 0)
            let glowColor = SIMD4<Float>(\(fmt(s.glowR)), \(fmt(s.glowG)), \(fmt(s.glowB)), 0)
            let spotColor = SIMD4<Float>(\(fmt(s.spotR)), \(fmt(s.spotG)), \(fmt(s.spotB)), 0)
            let glowAmount: Float = \(fmt(s.glowAmount))
            let accentMix: Float = \(fmt(s.accentMix))
            let dotSizeMin: Float = \(fmt(s.dotSizeMin))
            let dotSizeMax: Float = \(fmt(s.dotSizeMax))
            let fisheyeAmount: Float = \(fmt(s.fisheyeAmount))
            let dotShape: Float = \(fmt(s.dotShape))
            """

        case .neumorphicDigit:
            let s = NeumorphicDigitSpecs(state, sheet: sheet)
            return """
            // Generated by Component Studio · preset: \(presetLabel)
            // Neumorphic Digit — tap card to reveal productivity SF Symbols

            let iconSize: CGFloat = \(fmt(s.iconSize))
            let revealDelay: Double = \(fmt(s.revealDelay))
            let reveal: Animation = .spring(response: \(fmt(s.motionResponse)), dampingFraction: \(fmt(s.motionDamping)))
            let surfaceTone: Int = \(Int(s.surfaceTone))    // 0 white, 1 black, 2 sand, 3 slate, 4 ink
            """

        case .neumorphicPills:
            let s = NeumorphicPillsSpecs(state, sheet: sheet)
            return """
            // Generated by Component Studio · preset: \(presetLabel)
            // Neumorphic Pills — "+" pill pops in↔out (morphs + → ×) on tap

            let iconSize: CGFloat = \(fmt(s.iconSize))
            let surfaceTone: Int = \(Int(s.surfaceTone))
            let shadowOffset: CGFloat = \(fmt(s.shadowOffset))
            let shadowRadius: CGFloat = \(fmt(s.shadowRadius))
            let pillShadowIn: Double = \(fmt(s.pillShadowIn))
            let pillShadowOut: Double = \(fmt(s.pillShadowOut))
            let iconShadowIn: Double = \(fmt(s.iconShadowIn))
            let iconShadowOut: Double = \(fmt(s.iconShadowOut))
            \(s.motionEase
                ? "let transition: Animation = .easeInOut(duration: \(fmt(s.motionResponse)))"
                : "let transition: Animation = .spring(response: \(fmt(s.motionResponse)), dampingFraction: \(fmt(s.motionDamping)))")
            """

        case .sdfLiquid:
            let s = SDFLiquidSpecs(state, sheet: sheet)
            return """
            // Generated by Component Studio · preset: \(presetLabel)
            // SDF Liquid — Victor Baro draggable light blobs (smoothUnion merge)

            let smoothness: Float = \(fmt(s.smoothness))       // gooey bridge width (~0.1)
            let glowAmount: Float = \(fmt(s.glowAmount))
            let motionSpeed: CGFloat = \(fmt(s.motionSpeed))   // lava-lamp drift
            // ShaderLibrary.sdfLiquidBlobs via .colorEffect — drag orbs to merge
            """

        case .bubbleCard:
            return "// Satelite Cards exports code from its embedded toolbar."

        case .creditCard3D:
            let s = CreditCard3DSpecs(state, sheet: sheet)
            return """
            // Generated by Component Studio · preset: \(presetLabel)
            // AI Credit Card — 3D tilt + AI Search snake + particle trail

            let maxTilt: Double = \(fmt(s.maxTilt))
            let perspective: Double = \(fmt(s.perspective))
            let strokePeriod: Double = \(fmt(s.strokePeriod))
            let strokeWidth: CGFloat = \(fmt(s.strokeWidth))
            let auraOpacity: Double = \(fmt(s.auraOpacity))
            let particleCount: Int = \(Int(s.particleCount.rounded()))
            let particleDistance: CGFloat = \(fmt(s.particleDistance))
            let particleTrail: Double = \(fmt(s.particleTrail))
            """

        case .animatedCreditCard:
            let s = AnimatedCreditCardSpecs(state, sheet: sheet)
            return """
            // Generated by Component Studio · preset: \(presetLabel)
            // Imported Animated Credit Card — AI snake + projectile particles

            let strokePeriod: Double = \(fmt(s.strokePeriod))
            let strokeWidth: CGFloat = \(fmt(s.strokeWidth))
            let auraBlurRadius: CGFloat = \(fmt(s.auraBlurRadius))
            let auraOpacity: Double = \(fmt(s.auraOpacity))
            let particleCount: Int = \(Int(s.particleCount.rounded()))
            let particleDuration: Double = \(fmt(s.particleDuration))
            let speedRange: ClosedRange<Double> = \(fmt(s.minimumSpeed))...\(fmt(s.maximumSpeed))
            let gravity: Double = \(fmt(s.gravity))
            let particleSpreadDegrees: Double = \(fmt(s.particleSpreadDegrees))
            let maximumOpacity: Double = \(fmt(s.maximumOpacity))
            """

        case .flameInGlass:
            let s = FlameInGlassSpecs(state, sheet: sheet)
            return """
            // Generated by Component Studio · preset: \(presetLabel)
            // Flame in Glass — Glass Pill capsule (104×332) with a fill inside.

            let fill: Int = \(s.fill >= 0.5 ? 1 : 0)   // 0 = flame gradient, 1 = SDF liquid blobs
            // Liquid-blobs knobs (flame palette):
            let merge: Float = \(fmt(s.smoothness))
            let glow: Float  = \(fmt(s.glowAmount))
            let drift: CGFloat = \(fmt(s.motionSpeed))
            """

        case .flame:
            let s = FlameSpecs(state, sheet: sheet)
            return """
            // Generated by Component Studio · preset: \(presetLabel)
            // Flame — SDF metaball flame (flameSDF Metal shader)

            let height: Float = \(fmt(s.height))
            let width: Float = \(fmt(s.width))
            let flicker: Float = \(fmt(s.flicker))
            let speed: Float = \(fmt(s.speed))
            let softness: Float = \(fmt(s.softness))
            let glow: Float = \(fmt(s.glow))
            """
        }
    }

    private func fmt(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private static let allSpecSheets: [StudioItem: ComponentSpecSheet] = [
        .searchPillRest: searchPillSheet,
        .creditCard3D: creditCard3DSheet,
        .animatedCreditCard: animatedCreditCardSheet,
        .blurFocusLoading: blurFocusSheet,
        .verticalCardDeck: deckSheet,
        .sampleGlassPill: glassPillSheet,
        .talkPill: talkPillSheet,
        .photoRipple: photoRippleSheet,
        .photoRipple2: photoRipple2Sheet,
        .bubbleTextRipple: bubbleTextRippleSheet,
        .refractiveText: refractiveTextSheet,
        .dottedBackground: dottedBackgroundSheet,
        .neumorphicDigit: neumorphicDigitSheet,
        .neumorphicPills: neumorphicPillsSheet,
        .sdfLiquid: sdfLiquidSheet,
        .flameInGlass: flameInGlassSheet,
        .flame: flameSheet,
    ]

    private static let searchPillSheet = ComponentSpecSheet(
        categories: [
            ComponentSpecCategory(
                id: "motion",
                label: "Motion",
                controls: [
                    .init(id: "focusResponse", label: "Response", kind: .slider(0.20...0.80, format: "%.2f")),
                    .init(id: "focusDamping", label: "Damping", kind: .slider(0.50...1.00, format: "%.2f")),
                    .init(id: "focusScale", label: "Scale", kind: .slider(1.00...1.06, format: "%.3f")),
                ]
            ),
            ComponentSpecCategory(
                id: "aura",
                label: "Aura",
                controls: [
                    .init(id: "auraPeriodFocused", label: "Focus cycle", kind: .slider(1.0...6.0, format: "%.1fs")),
                    .init(id: "auraPeriodRest", label: "Rest cycle", kind: .slider(2.0...8.0, format: "%.1fs")),
                    .init(id: "snakeWidthFocused", label: "Stroke+", kind: .slider(0.6...2.0, format: "%.1f")),
                    .init(id: "snakeWidthRest", label: "Stroke", kind: .slider(0.4...1.6, format: "%.1f")),
                ]
            ),
        ],
        defaults: [
            "focusResponse": 0.42, "focusDamping": 0.78, "focusScale": 1.012,
            "auraPeriodFocused": 2.2, "auraPeriodRest": 4.2,
            "snakeWidthFocused": 1.2, "snakeWidthRest": 0.9,
        ]
    )

    private static let creditCard3DSheet = ComponentSpecSheet(
        categories: [
            ComponentSpecCategory(
                id: "motion",
                label: "3D Motion",
                controls: [
                    .init(id: "maxTilt", label: "Max tilt", kind: .slider(0.0...20.0, format: "%.0f°")),
                    .init(id: "perspective", label: "Perspective", kind: .slider(0.10...1.00, format: "%.2f")),
                ]
            ),
            ComponentSpecCategory(
                id: "snake",
                label: "AI Snake",
                controls: [
                    .init(id: "strokePeriod", label: "Cycle", kind: .slider(2.0...8.0, format: "%.1fs")),
                    .init(id: "strokeWidth", label: "Stroke", kind: .slider(0.4...1.6, format: "%.1f")),
                    .init(id: "auraOpacity", label: "Aura", kind: .slider(0.05...0.30, format: "%.2f")),
                ]
            ),
            ComponentSpecCategory(
                id: "particles",
                label: "Particles",
                controls: [
                    .init(id: "particleCount", label: "Count", kind: .slider(8.0...40.0, format: "%.0f")),
                    .init(id: "particleDistance", label: "Distance", kind: .slider(0.0...16.0, format: "%.0f")),
                    .init(id: "particleTrail", label: "Trail", kind: .slider(0.05...0.40, format: "%.2f")),
                ]
            ),
        ],
        defaults: [
            "maxTilt": 12.0,
            "perspective": 0.55,
            "strokePeriod": 4.2,
            "strokeWidth": 0.9,
            "auraOpacity": 0.13,
            "particleCount": 24.0,
            "particleDistance": 7.0,
            "particleTrail": 0.22,
        ]
    )

    private static let animatedCreditCardSheet = ComponentSpecSheet(
        categories: [
            ComponentSpecCategory(
                id: "snake",
                label: "AI Snake",
                controls: [
                    .init(id: "strokePeriod", label: "Cycle", kind: .slider(2.0...8.0, format: "%.1fs")),
                    .init(id: "strokeWidth", label: "Stroke", kind: .slider(0.4...1.6, format: "%.1f")),
                    .init(id: "auraBlurRadius", label: "Aura blur", kind: .slider(0.0...20.0, format: "%.0f")),
                    .init(id: "auraOpacity", label: "Aura", kind: .slider(0.05...0.30, format: "%.2f")),
                ]
            ),
            ComponentSpecCategory(
                id: "particles",
                label: "Particles",
                controls: [
                    .init(id: "particleCount", label: "Count", kind: .slider(8.0...48.0, format: "%.0f")),
                    .init(id: "particleDuration", label: "Lifetime", kind: .slider(0.5...4.0, format: "%.1fs")),
                    .init(id: "particleSpreadDegrees", label: "Spread", kind: .slider(5.0...70.0, format: "%.0f°")),
                    .init(id: "maximumOpacity", label: "Opacity", kind: .slider(0.20...1.00, format: "%.2f")),
                ]
            ),
            ComponentSpecCategory(
                id: "physics",
                label: "Physics",
                controls: [
                    .init(id: "minimumSpeed", label: "Min speed", kind: .slider(10.0...100.0, format: "%.0f")),
                    .init(id: "maximumSpeed", label: "Max speed", kind: .slider(20.0...140.0, format: "%.0f")),
                    .init(id: "gravity", label: "Gravity", kind: .slider(0.0...240.0, format: "%.0f")),
                ]
            ),
        ],
        defaults: [
            "strokePeriod": 4.2,
            "strokeWidth": 0.9,
            "auraBlurRadius": 10.0,
            "auraOpacity": 0.13,
            "particleCount": 24.0,
            "particleDuration": 2.0,
            "minimumSpeed": 40.0,
            "maximumSpeed": 80.0,
            "gravity": 147.15,
            "particleSpreadDegrees": 32.4,
            "maximumOpacity": 0.48,
        ]
    )

    private static let blurFocusSheet = ComponentSpecSheet(
        categories: [
            ComponentSpecCategory(
                id: "blur",
                label: "Blur",
                controls: [
                    .init(id: "blurAmount", label: "Blur", kind: .slider(4.0...16.0, format: "%.0f")),
                    .init(id: "blurRevealDuration", label: "Focus", kind: .slider(0.40...2.00, format: "%.2fs")),
                    .init(id: "wordStagger", label: "Stagger", kind: .slider(0.02...0.12, format: "%.2fs")),
                ]
            ),
            ComponentSpecCategory(
                id: "reveal",
                label: "Reveal",
                controls: [
                    .init(id: "cardStagger", label: "Card gap", kind: .slider(0.03...0.15, format: "%.2fs")),
                    .init(id: "cardRevealDuration", label: "Card ease", kind: .slider(0.25...0.90, format: "%.2fs")),
                    .init(id: "holdDuration", label: "Hold", kind: .slider(0.80...3.00, format: "%.2fs")),
                ]
            ),
        ],
        defaults: [
            "blurAmount": 9.0, "blurRevealDuration": 1.0, "wordStagger": 0.05,
            "cardStagger": 0.07, "cardRevealDuration": 0.5, "holdDuration": 1.9,
        ]
    )

    private static let deckSheet = ComponentSpecSheet(
        categories: [
            ComponentSpecCategory(
                id: "scroll",
                label: "Scroll",
                controls: [
                    .init(id: "edgeScale", label: "Edge scale", kind: .slider(0.70...0.95, format: "%.2f")),
                    .init(id: "edgeOpacity", label: "Edge fade", kind: .slider(0.10...0.60, format: "%.2f")),
                    .init(id: "maxEdgeBlur", label: "Edge blur", kind: .slider(0.0...12.0, format: "%.0f")),
                    .init(id: "parallaxAmount", label: "Parallax", kind: .slider(0.0...24.0, format: "%.0f")),
                ]
            ),
            ComponentSpecCategory(
                id: "settle",
                label: "Settle",
                controls: [
                    .init(id: "settleScale", label: "Breathe", kind: .slider(1.00...1.04, format: "%.3f")),
                    .init(id: "settleDuration", label: "Duration", kind: .slider(0.20...0.80, format: "%.2fs")),
                ]
            ),
        ],
        defaults: [
            "edgeScale": 0.84, "edgeOpacity": 0.30, "maxEdgeBlur": 6.0,
            "parallaxAmount": 14.0, "settleScale": 1.012, "settleDuration": 0.4,
        ]
    )

    private static let glassPillSheet = ComponentSpecSheet(
        categories: [
            ComponentSpecCategory(
                id: "glass",
                label: "Glass",
                controls: [
                    .init(id: "glassOpacity", label: "Opacity", kind: .slider(0.15...1.0, format: "%.2f")),
                    .init(id: "tintOpacity", label: "Tint", kind: .slider(0.0...0.60, format: "%.2f")),
                ]
            ),
            ComponentSpecCategory(
                id: "motion",
                label: "Motion",
                controls: [
                    .init(id: "restScale", label: "Scale", kind: .slider(0.96...1.04, format: "%.3f")),
                    .init(id: "pressPop", label: "Pop", kind: .slider(0.0...0.14, format: "%.2f")),
                    .init(id: "pressScale", label: "Press", kind: .slider(0.88...1.0, format: "%.2f")),
                ]
            ),
        ],
        defaults: [
            "glassOpacity": 0.52,
            "tintOpacity": 0.0,
            "restScale": 1.04,
            "pressPop": 0.09,
            "pressScale": 1.0,
        ]
    )

    private static let talkPillSheet = ComponentSpecSheet(
        categories: [
            ComponentSpecCategory(
                id: "glass",
                label: "Glass",
                controls: [
                    .init(id: "glassOpacity", label: "Opacity", kind: .slider(0.15...1.0, format: "%.2f")),
                    .init(id: "tintOpacity", label: "Tint", kind: .slider(0.0...0.60, format: "%.2f")),
                ]
            ),
            ComponentSpecCategory(
                id: "motion",
                label: "Motion",
                controls: [
                    .init(id: "restScale", label: "Scale", kind: .slider(0.96...1.04, format: "%.3f")),
                    .init(id: "pressPop", label: "Pop", kind: .slider(0.0...0.14, format: "%.2f")),
                    .init(id: "pressScale", label: "Press", kind: .slider(0.88...1.0, format: "%.2f")),
                    .init(id: "morphBlur", label: "Morph", kind: .slider(8...40, format: "%.0f")),
                ]
            ),
            ComponentSpecCategory(
                id: "wave",
                label: "Wave",
                controls: [
                    .init(id: "waveSpeed", label: "Speed", kind: .slider(0.40...2.40, format: "%.2f")),
                    .init(id: "waveAmplitude", label: "Amp", kind: .slider(0.20...1.00, format: "%.2f")),
                ]
            ),
        ],
        defaults: [
            "glassOpacity": 0.52,
            "tintOpacity": 0.0,
            "restScale": 1.04,
            "pressPop": 0.09,
            "pressScale": 1.0,
            "morphBlur": 36,
            "waveSpeed": 1.15,
            "waveAmplitude": 0.72,
        ]
    )

    private static let photoRippleSheet = ComponentSpecSheet(
        categories: [
            ComponentSpecCategory(
                id: "wave",
                label: "Wave",
                controls: [
                    .init(id: "amplitude", label: "Amplitude", kind: .slider(5...60, format: "%.0f")),
                    .init(id: "frequency", label: "Frequency", kind: .slider(4...30, format: "%.0f")),
                    .init(id: "speed", label: "Speed", kind: .slider(400...2000, format: "%.0f")),
                ]
            ),
            ComponentSpecCategory(
                id: "feel",
                label: "Feel",
                controls: [
                    .init(id: "decay", label: "Decay", kind: .slider(3...12, format: "%.1f")),
                    .init(id: "highlight", label: "Highlight", kind: .slider(0.10...0.80, format: "%.2f")),
                    .init(id: "duration", label: "Duration", kind: .slider(0.8...3.0, format: "%.1fs")),
                ]
            ),
        ],
        defaults: [
            "amplitude": 31, "frequency": 16, "decay": 3.0,
            "speed": 400, "highlight": 0.43, "duration": 3.0,
        ]
    )

    private static let photoRipple2Sheet = ComponentSpecSheet(
        categories: [
            ComponentSpecCategory(
                id: "wave",
                label: "Wave",
                controls: [
                    .init(id: "speed", label: "Speed", kind: .slider(200...1400, format: "%.0f")),
                    .init(id: "bandWidth", label: "Band", kind: .slider(24...140, format: "%.0f")),
                    .init(id: "maxRadius", label: "Max R", kind: .slider(200...900, format: "%.0f")),
                    .init(id: "displacement", label: "Crest", kind: .slider(0...40, format: "%.0f")),
                ]
            ),
            ComponentSpecCategory(
                id: "glass",
                label: "Glass",
                controls: [
                    .init(id: "refract", label: "Refract", kind: .slider(0...90, format: "%.0f")),
                    .init(id: "glint", label: "Glint", kind: .slider(0...0.8, format: "%.2f")),
                    .init(id: "chromatic", label: "Chroma", kind: .slider(0...1.5, format: "%.2f")),
                    .init(id: "falloff", label: "Falloff", kind: .slider(1.0...12.0, format: "%.1f")),
                    .init(id: "swirl", label: "Swirl", kind: .slider(0.0...2.5, format: "%.2f")),
                ]
            ),
            ComponentSpecCategory(
                id: "trail",
                label: "Trail",
                controls: [
                    .init(id: "life", label: "Life", kind: .slider(0.8...2.5, format: "%.1fs")),
                    .init(id: "emitSpacing", label: "Spacing", kind: .slider(8...60, format: "%.0f")),
                ]
            ),
        ],
        defaults: [
            "speed": 200, "bandWidth": 24, "maxRadius": 900,
            "refract": 90, "glint": 0.48, "falloff": 1.0, "swirl": 0.0,
            "displacement": 9.22, "life": 0.8, "emitSpacing": 60, "chromatic": 0.00,
        ]
    )

    // Shared lens controls for all refractive-glass components (no edge/shadow chrome).
    private static let refractiveLensCategories: [ComponentSpecCategory] = [
        ComponentSpecCategory(
            id: "lens",
            label: "Lens",
            controls: [
                .init(id: "refraction", label: "Refract", kind: .slider(0.0...1.2, format: "%.2f")),
                .init(id: "falloff", label: "Falloff", kind: .slider(1.0...16.0, format: "%.1f")),
                .init(id: "swirl", label: "Swirl", kind: .slider(0.0...6.28, format: "%.2f")),
                .init(id: "glassRadius", label: "Radius", kind: .slider(60...260, format: "%.0f")),
                .init(id: "chromatic", label: "Chroma", kind: .slider(0.0...0.4, format: "%.2f")),
            ]
        ),
    ]

    // Refractive Sphere — default tuning from reference screenshots.
    private static let bubbleTextRippleSheet = ComponentSpecSheet(
        categories: refractiveLensCategories,
        defaults: [
            "refraction": 0.95, "falloff": 8.1, "swirl": 0.00, "glassRadius": 88, "chromatic": 0.00,
        ]
    )

    // Refractive Text — liquid typography + ping-pong glass lens on text only.
    private static let refractiveTextSheet = ComponentSpecSheet(
        categories: refractiveLensCategories,
        defaults: [
            "refraction": 0.70, "falloff": 14.2, "swirl": 1.12, "glassRadius": 82, "chromatic": 0.04,
        ]
    )

    private static let dottedBackgroundSheet = ComponentSpecSheet(
        categories: [
            ComponentSpecCategory(
                id: "interaction",
                label: "Interaction",
                controls: [
                    .init(id: "mode", label: "Mode", kind: .slider(0.0...2.0, format: "%.0f")),
                    .init(id: "influenceRadius", label: "Radius", kind: .slider(0.15...0.60, format: "%.2f")),
                    .init(id: "maxDisplacement", label: "Push", kind: .slider(0.10...1.00, format: "%.2f")),
                    .init(id: "fisheyeAmount", label: "Fisheye", kind: .slider(0.0...0.50, format: "%.2f")),
                ]
            ),
            ComponentSpecCategory(
                id: "grid",
                label: "Grid",
                controls: [
                    .init(id: "gridDensity", label: "Density", kind: .slider(20.0...60.0, format: "%.0f")),
                    .init(id: "dotSizeMin", label: "Dot min", kind: .slider(0.06...0.20, format: "%.2f")),
                    .init(id: "dotSizeMax", label: "Dot max", kind: .slider(0.14...0.35, format: "%.2f")),
                    .init(id: "dotShape", label: "Shape", kind: .slider(0.0...1.0, format: "%.2f")),
                ]
            ),
            ComponentSpecCategory(
                id: "palette",
                label: "Palette",
                controls: [
                    .init(id: "glowAmount", label: "Glow", kind: .slider(0.0...1.0, format: "%.2f")),
                    .init(id: "accentMix", label: "Accent", kind: .slider(0.0...1.0, format: "%.2f")),
                    .init(id: "spotR", label: "Spot R", kind: .slider(0.0...1.0, format: "%.2f")),
                    .init(id: "spotG", label: "Spot G", kind: .slider(0.0...1.0, format: "%.2f")),
                    .init(id: "spotB", label: "Spot B", kind: .slider(0.0...1.0, format: "%.2f")),
                ]
            ),
        ],
        defaults: [
            // Tuned "Pinned 4" promoted to default — black canvas, cyan
            // repel dots, dome fisheye.
            "mode": 1.0, "gridDensity": 60.0,
            "influenceRadius": 0.60, "maxDisplacement": 0.10,
            "fisheyeAmount": 0.29, "dotShape": 0.0,
            "bgR": 0.0, "bgG": 0.0, "bgB": 0.0,
            "bg2R": 0.0, "bg2G": 0.0, "bg2B": 0.0,
            "dotR": 1.0, "dotG": 1.0, "dotB": 1.0,
            "accentR": 0.0, "accentG": 0.85, "accentB": 1.0,
            "glowR": 0.0, "glowG": 0.85, "glowB": 1.0,
            "spotR": 0.0, "spotG": 0.85, "spotB": 1.0,
            "glowAmount": 0.0, "accentMix": 0.0,
            "dotSizeMin": 0.12, "dotSizeMax": 0.22,
        ]
    )

    private static let sdfLiquidSheet = ComponentSpecSheet(
        categories: [
            ComponentSpecCategory(
                id: "liquid",
                label: "Liquid",
                controls: [
                    .init(id: "smoothness", label: "Merge", kind: .slider(0.04...0.22, format: "%.3f")),
                    .init(id: "glowAmount", label: "Glow", kind: .slider(0.0...1.0, format: "%.2f")),
                    .init(id: "motionSpeed", label: "Drift", kind: .slider(0.0...0.12, format: "%.3f")),
                ]
            ),
            ComponentSpecCategory(
                id: "motion",
                label: "Motion",
                controls: [
                    .init(id: "springStrength", label: "Spring", kind: .slider(2.0...24.0, format: "%.1f")),
                    .init(id: "damping", label: "Damping", kind: .slider(0.70...0.98, format: "%.2f")),
                ]
            ),
        ],
        defaults: [
            "smoothness": 0.10,
            "glowAmount": 0.72,
            "motionSpeed": 0.045,
            "springStrength": 14.0,
            "damping": 0.88,
        ]
    )

    // Flame in Glass — `fill` is preset-driven (not a slider); the Liquid
    // knobs tune the SDF liquid-blobs option.
    private static let flameInGlassSheet = ComponentSpecSheet(
        categories: [
            ComponentSpecCategory(
                id: "liquid",
                label: "Liquid",
                controls: [
                    .init(id: "smoothness", label: "Merge", kind: .slider(0.04...0.22, format: "%.3f")),
                    .init(id: "glowAmount", label: "Glow", kind: .slider(0.0...1.0, format: "%.2f")),
                    .init(id: "motionSpeed", label: "Drift", kind: .slider(0.0...0.12, format: "%.3f")),
                ]
            ),
        ],
        defaults: [
            "fill": 0.0,
            "smoothness": 0.182,
            "glowAmount": 0.35,
            "motionSpeed": 0.120,
        ]
    )

    // Standalone SDF Flame component.
    private static let flameSheet = ComponentSpecSheet(
        categories: [
            ComponentSpecCategory(
                id: "flame",
                label: "Flame",
                controls: [
                    .init(id: "flameHeight", label: "Height", kind: .slider(0.5...1.5, format: "%.2f")),
                    .init(id: "flameWidth", label: "Width", kind: .slider(0.5...1.5, format: "%.2f")),
                    .init(id: "flameFlicker", label: "Flicker", kind: .slider(0.0...2.0, format: "%.2f")),
                    .init(id: "flameSpeed", label: "Speed", kind: .slider(0.2...3.0, format: "%.2f")),
                    .init(id: "flameSoftness", label: "Softness", kind: .slider(0.02...0.30, format: "%.2f")),
                    .init(id: "flameGlow", label: "Glow", kind: .slider(0.0...1.5, format: "%.2f")),
                ]
            ),
        ],
        defaults: [
            "flameHeight": 1.0,
            "flameWidth": 1.0,
            "flameFlicker": 1.0,
            "flameSpeed": 1.0,
            "flameSoftness": 0.13,
            "flameGlow": 0.55,
        ]
    )

    private static let neumorphicDigitSheet = ComponentSpecSheet(
        categories: [
            ComponentSpecCategory(
                id: "display",
                label: "Display",
                controls: [
                    .init(id: "iconSize", label: "Icon", kind: .slider(32...80, format: "%.0f")),
                    .init(id: "surfaceTone", label: "Surface", kind: .slider(0.0...4.0, format: "%.0f")),
                    .init(id: "iconOpacity", label: "Opacity", kind: .slider(0.0...1.0, format: "%.2f")),
                    .init(id: "iconColor", label: "Color", kind: .color),
                ]
            ),
            ComponentSpecCategory(
                id: "shadow",
                label: "Shadow",
                controls: [
                    .init(id: "shadowOffsetX", label: "Offset X", kind: .slider(-16.0...16.0, format: "%.0f")),
                    .init(id: "shadowOffsetY", label: "Offset Y", kind: .slider(-16.0...16.0, format: "%.0f")),
                    .init(id: "shadowRadius", label: "Blur", kind: .slider(0.0...20.0, format: "%.0f")),
                    .init(id: "shadowOpacity", label: "Strength", kind: .slider(0.0...1.0, format: "%.2f")),
                ]
            ),
            ComponentSpecCategory(
                id: "motion",
                label: "Motion",
                controls: [
                    .init(id: "motionResponse", label: "Response", kind: .slider(0.1...1.0, format: "%.2f")),
                    .init(id: "motionDamping", label: "Damping", kind: .slider(0.4...1.0, format: "%.2f")),
                    .init(id: "revealDelay", label: "Delay", kind: .slider(0.0...1.2, format: "%.1fs")),
                ]
            ),
        ],
        defaults: [
            "iconSize": 80.0,
            "surfaceTone": 0.0,
            "iconOpacity": 0.90,
            "motionResponse": 0.45,
            "motionDamping": 0.78,
            "revealDelay": 0.0,
            "shadowOffsetX": 1.0,
            "shadowOffsetY": 9.0,
            "shadowRadius": 2.0,
            "shadowOpacity": 0.01,
            // Icon color — white.
            "iconColorR": 1.0,
            "iconColorG": 1.0,
            "iconColorB": 1.0,
        ]
    )

    private static let neumorphicPillsSheet = ComponentSpecSheet(
        categories: [
            ComponentSpecCategory(
                id: "display",
                label: "Display",
                controls: [
                    .init(id: "iconSize", label: "Icon", kind: .slider(32...140, format: "%.0f")),
                    .init(id: "surfaceTone", label: "Surface", kind: .slider(0.0...4.0, format: "%.0f")),
                    .init(id: "shadowOffset", label: "Offset", kind: .slider(0.0...16.0, format: "%.0f")),
                    .init(id: "shadowRadius", label: "Blur", kind: .slider(0.0...20.0, format: "%.0f")),
                ]
            ),
            ComponentSpecCategory(
                id: "pillShadow",
                label: "Pill",
                controls: [
                    .init(id: "pillShadowIn", label: "Shadow in", kind: .slider(0.0...1.0, format: "%.2f")),
                    .init(id: "pillShadowOut", label: "Shadow out", kind: .slider(0.0...1.0, format: "%.2f")),
                ]
            ),
            ComponentSpecCategory(
                id: "iconShadow",
                label: "Icon",
                controls: [
                    .init(id: "iconShadowIn", label: "Shadow in", kind: .slider(0.0...1.0, format: "%.2f")),
                    .init(id: "iconShadowOut", label: "Shadow out", kind: .slider(0.0...1.0, format: "%.2f")),
                ]
            ),
            ComponentSpecCategory(
                id: "motion",
                label: "Motion",
                controls: [
                    .init(id: "motionEase", label: "Ease", kind: .toggle),
                    .init(id: "motionResponse", label: "Response", kind: .slider(0.1...1.0, format: "%.2f")),
                    .init(id: "motionDamping", label: "Damping", kind: .slider(0.4...1.0, format: "%.2f")),
                ]
            ),
        ],
        defaults: [
            "iconSize": 73.0,
            "surfaceTone": 0.0,
            "shadowOffset": 1.17,
            "shadowRadius": 2.29,
            "pillShadowIn": 0.62,
            "pillShadowOut": 0.46,
            "iconShadowIn": 1.0,
            "iconShadowOut": 1.0,
            "motionEase": 1.0,
            "motionResponse": 0.60,
            "motionDamping": 1.00,
        ]
    )

    // MARK: - Presets

    private static let searchPillPresets: [StudioComponentPreset] = [
        .init(id: "default", label: "Default", values: [:]),
    ]

    private static let creditCard3DPresets: [StudioComponentPreset] = [
        .init(id: "default", label: "AI Search", values: [:]),
    ]

    private static let animatedCreditCardPresets: [StudioComponentPreset] = [
        .init(id: "default", label: "PR 3 Original", values: [:]),
    ]

    private static let blurFocusPresets: [StudioComponentPreset] = [
        .init(id: "default", label: "Default", values: [:]),
    ]

    private static let deckPresets: [StudioComponentPreset] = [
        .init(id: "default", label: "Default", values: [:]),
    ]

    private static let glassPillPresets: [StudioComponentPreset] = [
        .init(id: "default", label: "Default", values: [:]),
    ]

    private static let talkPillPresets: [StudioComponentPreset] = [
        .init(id: "default", label: "Default", values: [:]),
    ]

    private static let photoRipplePresets: [StudioComponentPreset] = [
        .init(id: "default", label: "Default", values: [:]),
    ]

    private static let photoRipple2Presets: [StudioComponentPreset] = [
        .init(id: "default", label: "Default", values: [:]),
    ]

    private static let bubbleTextRipplePresets: [StudioComponentPreset] = [
        .init(id: "default", label: "Default", values: [:]),
    ]

    private static let refractiveTextPresets: [StudioComponentPreset] = [
        .init(id: "default", label: "Default", values: [:]),
    ]

    private static let dottedBackgroundPresets: [StudioComponentPreset] = [
        .init(id: "default", label: "Default", values: [:]),
        // Baked from the user's runtime pin "Pinned 2" — white canvas,
        // blue attract dots.
        .init(id: "pinned-2", label: "Pinned 2", values: [
            "mode": 1, "gridDensity": 20, "influenceRadius": 0.4035,
            "maxDisplacement": 1.0, "fisheyeAmount": 0.0, "dotShape": 0,
            "bgR": 0.98, "bgG": 0.98, "bgB": 1.0,
            "bg2R": 0.94, "bg2G": 0.96, "bg2B": 1.0,
            "dotR": 0.22, "dotG": 0.50, "dotB": 0.94,
            "accentR": 0.12, "accentG": 0.38, "accentB": 0.88,
            "glowR": 0.35, "glowG": 0.62, "glowB": 1.0,
            "spotR": 0, "spotG": 0, "spotB": 0,
            "glowAmount": 0, "accentMix": 1.0,
            "dotSizeMin": 0.06, "dotSizeMax": 0.1983,
        ]),
        // Baked from the user's runtime pin "Pinned 4" — black canvas,
        // cyan repel dots with fisheye.
        .init(id: "pinned-4", label: "Pinned 4", values: [
            "mode": 1.3028, "gridDensity": 40, "influenceRadius": 0.4,
            "maxDisplacement": 0.65, "fisheyeAmount": 0.12, "dotShape": 0,
            "bgR": 0, "bgG": 0, "bgB": 0,
            "bg2R": 0, "bg2G": 0, "bg2B": 0,
            "dotR": 1.0, "dotG": 1.0, "dotB": 1.0,
            "accentR": 0, "accentG": 0.85, "accentB": 1.0,
            "glowR": 0, "glowG": 0.85, "glowB": 1.0,
            "spotR": 0, "spotG": 0.85, "spotB": 1.0,
            "glowAmount": 0, "accentMix": 0,
            "dotSizeMin": 0.12, "dotSizeMax": 0.22,
        ]),
    ]

    private static let neumorphicDigitPresets: [StudioComponentPreset] = [
        .init(id: "default", label: "Default", values: [:]),
    ]

    private static let neumorphicPillsPresets: [StudioComponentPreset] = [
        .init(id: "default", label: "Default", values: [:]),
    ]

    private static let sdfLiquidPresets: [StudioComponentPreset] = [
        .init(id: "default", label: "Default", values: [:]),
    ]

    private static let flameInGlassPresets: [StudioComponentPreset] = [
        // Default — the original traveling flame gradient.
        .init(id: "default", label: "Flame", values: ["fill": 0]),
        // Liquid blobs (flame palette) at the attached specs.
        .init(id: "liquid-blobs", label: "Liquid Blobs", values: [
            "fill": 1,
            "smoothness": 0.220,
            "glowAmount": 0.35,
            "motionSpeed": 0.120,
        ]),
    ]

    private static let flamePresets: [StudioComponentPreset] = [
        .init(id: "default", label: "Default", values: [:]),
    ]
}
