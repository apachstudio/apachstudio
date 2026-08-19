import SwiftUI

/// Geometric design tokens. iOS 26 system materials and `Color.primary`
/// / `Color.secondary` do all the colour work — `Theme` only owns the
/// reusable radii and spacing values so components don't sprinkle
/// magic numbers.
///
/// Add to this when (and only when) a value is reused in ≥ 2 places.
enum Theme {
    /// Corner radii used by the standard surfaces.
    enum Radius {
        static let chip: CGFloat   = 14
        static let card: CGFloat   = 28
        static let sheet: CGFloat  = 44
        /// `Capsule()` is usually clearer than `RoundedRectangle(cornerRadius: pill)`,
        /// but the constant is here for cases where a numeric radius is required.
        static let pill: CGFloat   = 999
    }

    /// 8-pt grid. Stick to these values; anything else is suspicious.
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat  = 8
        static let sm: CGFloat  = 12
        static let md: CGFloat  = 16
        static let lg: CGFloat  = 20
        static let xl: CGFloat  = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }
}
