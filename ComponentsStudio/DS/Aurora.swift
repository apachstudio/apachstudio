import SwiftUI
import UIKit

/// Aurora design tokens (the subset this screen uses).
/// Mirrors `theme/tokens.ts` / `theme/aurora.tokens.json` from the RN app.
enum Aurora {
    // Brand
    static let ink = Color(hex: 0x16161A)         // text.primary
    static let canvas = Color(hex: 0xFFFFFF)      // neutral.0
    static let cardInk = Color(hex: 0x10161A)     // photo slot / hero backing

    // Studio redesign tokens (Figma node 103:3914) — flat black-on-white catalog.
    static let iconInk = Color(hex: 0x1A1A1A)     // back chevron / FAB glyphs
    static let listArrow = Color(hex: 0x1E1E1E)   // trailing "→" on list rows
    static let rule = Color(hex: 0x000000)        // 1px table rails + row separators

    /// Brand accent. Was `lime` (#CDE34D); replaced with ink @ 80% for a
    /// quieter, more premium tone. Use for interactive accents, badges,
    /// `.tint(_:)`, and any element that previously read as "lime."
    static let accent = Color(hex: 0x16161A, alpha: 0.8)

    /// Legacy alias — points at `.accent` so existing call sites keep
    /// compiling. New code should reach for `Aurora.accent` directly.
    static let lime: Color = accent

    /// Solid violet pulled from the AI palette — used for the typed query
    /// text when the search pill is focused in AI mode. Must be solid (not
    /// the `AI.still` gradient): an editable `TextField` won't render a
    /// gradient foreground, so a gradient there makes the text invisible.
    /// Deeper than the `AI.stops` violet for legibility on white glass.
    static let aiTextSolid = Color(red: 0.55, green: 0.30, blue: 0.95)

    /// AI/Intelligence palette — original Apple Intelligence-style 4-color:
    /// indigo → violet → magenta → coral. Used by the headline query word,
    /// the summary keyword highlights, and the search pill's snake stroke.
    enum AI {
        static let stops: [Color] = [
            Color(red: 0.40, green: 0.30, blue: 1.00),  // indigo
            Color(red: 0.74, green: 0.38, blue: 1.00),  // violet
            Color(red: 1.00, green: 0.45, blue: 0.62),  // magenta
            Color(red: 1.00, green: 0.62, blue: 0.40),  // coral
        ]

        /// Instagram-style continuous shimmer flow — colors travel left→right
        /// at a steady pace and loop seamlessly. The doubled color array
        /// guarantees no visible jump at the loop boundary.
        ///
        /// Pass a monotonically increasing `time` (from `TimelineView`).
        static func drifting(time: Double) -> LinearGradient {
            let cycle: Double = 1.6              // one full sweep in 1.6s
            let phase = (time / cycle).truncatingRemainder(dividingBy: 1)
            return LinearGradient(
                colors: stops + stops,           // 8 colors, loops cleanly
                startPoint: UnitPoint(x: -phase,        y: 0),
                endPoint:   UnitPoint(x:  2.0 - phase,  y: 0)
            )
        }

        /// Static gradient — used after thinking settles.
        static let still = LinearGradient(
            colors: stops,
            startPoint: .leading, endPoint: .trailing
        )
    }

    // Radii (px)
    enum Radius {
        static let card: CGFloat = 44   // radius.2xl
        static let photo: CGFloat = 40
        static let pill: CGFloat = 999
    }
}

extension Color {
    /// `Color(hex: 0xCDE34D)` — convenience for the token hex values.
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

/// Type ramp. Aurora uses **Manrope** (sans) and **Mea Culpa** (the script used
/// for the "Places" hero). Drop the TTFs into the project + Info.plist
/// (UIAppFonts) and these helpers pick them up automatically; until then they
/// fall back to a tasteful system equivalent so everything compiles + runs.
enum AppFont {
    /// Sans-serif type. `relativeTo:` makes the font Dynamic-Type-aware —
    /// it scales when the user picks a larger accessibility text size.
    /// `Font.custom(_:size:relativeTo:)` keeps the scaling even when the
    /// requested face isn't bundled (iOS auto-falls back to the system font).
    static func manrope(
        _ size: CGFloat,
        _ weight: Font.Weight = .regular,
        relativeTo style: Font.TextStyle = .body
    ) -> Font {
        let name = manropeName(weight)
        return .custom(name, size: size, relativeTo: style).weight(weight)
    }

    /// SF Pro Display Bold — the studio redesign's single display face
    /// (Figma node 103:3914). The system serves SF Pro Display for
    /// `design: .default` at large sizes and SF Pro Text at smaller ones;
    /// the optical difference is negligible for our weights.
    static func display(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    /// Decorative script for hero moments. Falls back through Snell Roundhand
    /// → system serif italic. `relativeTo:` keeps Dynamic Type scaling intact.
    static func script(
        _ size: CGFloat,
        relativeTo style: Font.TextStyle = .title2
    ) -> Font {
        if UIFont(name: "MeaCulpa-Regular", size: size) != nil {
            return .custom("MeaCulpa-Regular", size: size, relativeTo: style)
        }
        if UIFont(name: "SnellRoundhand", size: size) != nil {
            return .custom("SnellRoundhand", size: size, relativeTo: style)
        }
        return .system(style, design: .serif).italic()
    }

    /// Dripdrop display face for Refractive Text ("apach").
    static func dripdrop(
        _ size: CGFloat,
        relativeTo style: Font.TextStyle = .largeTitle
    ) -> Font {
        let postScript = "Dripdrop-Regular"
        if UIFont(name: postScript, size: size) != nil {
            return .custom(postScript, size: size, relativeTo: style)
        }
        return .system(size: size, weight: .bold, design: .default)
    }

    private static func manropeName(_ w: Font.Weight) -> String {
        switch w {
        case .ultraLight, .thin: return "Manrope-ExtraLight"
        case .light:             return "Manrope-Light"
        case .medium:            return "Manrope-Medium"
        case .semibold:          return "Manrope-SemiBold"
        case .bold, .heavy, .black: return "Manrope-Bold"
        default:                 return "Manrope-Regular"
        }
    }
}
