import AppKit
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
        public static let setupWidth: CGFloat = 520
        public static let setupHeight: CGFloat = 640
        public static let providerLogo: CGFloat = 14
        public static let edgeLine: CGFloat = 1
        /// How far the pointer travels before a press on the capsule becomes a drag.
        public static let dragStart: CGFloat = 4
        public static let dotHoverScale: CGFloat = 1.08
        public static let tooltipMaximumWidth: CGFloat = 280
        public static let pillMaximumWidth: CGFloat = 120
        public static let setupIcon: CGFloat = 24
    }

    public enum Capsule {
        public static let maximumDots = 6
    }

    /// The docked tab and the dragging that moves the capsule to and from it.
    public enum Dock {
        /// How far the tab stands out from the screen edge, and the room around its marks.
        public static let tabDepth: CGFloat = 22
        public static let tabPadding: CGFloat = 14
        public static let markSize: CGFloat = 10
        public static let tabCorner: CGFloat = 11
        /// The concave curve where the tab meets the edge, running out along it.
        public static let flareRadius: CGFloat = 14
        /// Released this close to an edge, the capsule docks; from this far it starts to be pulled in.
        public static let snapDistance: CGFloat = 56
        public static let pullDistance: CGFloat = 96
        /// A docked tab dragged this far from its edge comes away as a capsule.
        public static let detachDistance: CGFloat = 28
        /// Extra room a horizontal capsule needs before it turns upright again.
        public static let reflowSlack: CGFloat = 24
    }

    /// Tracing the liquid outline: the finest grid spacing, the most grid cells per frame (a large shape is traced
    /// more coarsely), and the fusion below which the shape is just its rounded rectangle.
    public enum Liquid {
        static let step: CGFloat = 1
        static let maximumCells: CGFloat = 24_000
        static let minimumReach: CGFloat = 0.25
    }

    /// The face shown on a docked tab when no chat is waiting or working: a plain round body with two eyes.
    public enum Mascot {
        static let size: CGFloat = 16
        static let eyeWidth: CGFloat = 3
        static let eyeHeight: CGFloat = 4.5
        static let eyeGap: CGFloat = 2.5
        static let mouthWidth: CGFloat = 4
        static let mouthHeight: CGFloat = 2
        static let mouthInset: CGFloat = 2
        static let listeningSize: CGFloat = 20
        /// How far the eyes sit above the body's centre, and how far they turn towards the middle of the screen.
        static let eyeLift: CGFloat = 1
        static let gaze: CGFloat = 1.5
    }

    public enum Surface {
        /// The material under the capsule, the pane and the label: what a native menu is made of.
        static let material = NSVisualEffectView.Material.menu
    }

    public enum Motion {
        /// One settle-bounce: the shape grows slightly past its size, then rests.
        public static let springDuration: TimeInterval = 0.42
        public static let springBounce: Double = 0.3
        /// Reduce Motion: a brief fade with no overshoot.
        public static let reducedDuration: TimeInterval = 0.12
        /// The capsule's dots are gone by `capsuleFadeEnd` of the shape's progress. The content has its own
        /// timeline: it starts at `contentRevealStart`, each row follows the one before by `staggerStep`, and
        /// the last row is fully visible only at the very end of the move.
        public static let capsuleFadeEnd = 0.3
        public static let contentRevealStart = 0.25
        public static let contentRevealSpan = 0.45
        public static let staggerStep = 0.035
        /// Closing runs the content's timeline this much faster than opening.
        public static let contentCloseFraction = 0.4
        public static let staggerLimit = 8
        public static let rowRise: CGFloat = 6
        /// The capsule's label: in and out are quick, gliding to the next dot quicker, and it starts a little smaller.
        public static let tooltipIn: TimeInterval = 0.14
        public static let tooltipOut: TimeInterval = 0.12
        public static let tooltipGlide: TimeInterval = 0.09
        public static let tooltipFade: TimeInterval = 0.06
        public static let dotHover: TimeInterval = 0.1
        public static let tooltipEntryScale: CGFloat = 0.9
        /// How long a peeking capsule stays out after the pointer has left it, and how long presses are ignored after a drag.
        public static let peekGrace: Duration = .milliseconds(450)
        public static let clickGuard: TimeInterval = 0.25
        /// Extra window around the pane while it opens, so the overshoot of the bounce is not clipped.
        public static let overshootMargin: CGFloat = 24
    }
}
