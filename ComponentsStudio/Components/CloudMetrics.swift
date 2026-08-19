import CoreGraphics

/// Bubble card sizing constants from bubble-cloud's `CloudMath`.
/// Only the subset needed by `BubbleView` and `ExpandingBubbleCard`.
enum Cloud {
    static let bubbleAspect: CGFloat = 1.25
    static let bubbleW: CGFloat = 120
    static let bubbleH: CGFloat = bubbleW * bubbleAspect
}
