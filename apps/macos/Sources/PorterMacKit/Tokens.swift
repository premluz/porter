import CoreGraphics
import Foundation

/// Design tokens. Values are starting points from docs/UX_DESIGN.md, to be tuned by looking at
/// the real panel, so they live here and nowhere else.
public enum Tokens {
    public enum Space {
        public static let xs: CGFloat = 4
        public static let s: CGFloat = 8
        public static let m: CGFloat = 12
        public static let l: CGFloat = 16
        public static let xl: CGFloat = 24
    }

    public enum Size {
        public static let capsuleWidth: CGFloat = 40
        public static let paneWidth: CGFloat = 360
        public static let rowHeight: CGFloat = 56
        public static let searchHeight: CGFloat = 36
        public static let headerHeight: CGFloat = 52
        public static let footerHeight: CGFloat = 32
        public static let sectionHeaderHeight: CGFloat = 28
        public static let statusDot: CGFloat = 10
        public static let capsuleDot: CGFloat = 26
        public static let expandButton: CGFloat = 28
        public static let capsuleCorner: CGFloat = 20
        public static let paneCorner: CGFloat = 28
        public static let edgeMargin: CGFloat = 8
        public static let minimumPaneHeight: CGFloat = 160
    }

    public enum Capsule {
        public static let maximumDots = 6
    }

    public enum Motion {
        /// One settle-bounce: the shape grows slightly past its size, then rests.
        public static let springDuration: TimeInterval = 0.42
        public static let springBounce: Double = 0.3
        /// Reduce Motion: a brief fade with no overshoot.
        public static let reducedDuration: TimeInterval = 0.12
        /// Fractions of the move: the capsule's dots are gone by `capsuleFadeEnd`; the pane's content starts
        /// at `contentRevealStart` and each row follows the one before by `staggerStep`.
        public static let capsuleFadeEnd = 0.3
        public static let contentRevealStart = 0.3
        public static let contentRevealSpan = 0.35
        public static let staggerStep = 0.03
        public static let staggerLimit = 8
        public static let rowRise: CGFloat = 6
        /// Extra window around the pane while it opens, so the overshoot of the bounce is not clipped.
        public static let overshootMargin: CGFloat = 24
    }
}
