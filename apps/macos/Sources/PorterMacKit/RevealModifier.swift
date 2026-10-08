import SwiftUI

extension View {
    /// Fades and lifts content in after the shape has begun to grow, one step later per position,
    /// and hides it quickly on the way out so text is never seen on a shrinking shape.
    func reveal(_ revealed: Bool, order: Int) -> some View {
        let step = Tokens.Motion.staggerStep * Double(min(order, Tokens.Motion.staggerLimit))
        let showing = Animation.easeOut(duration: Tokens.Motion.contentFade).delay(Tokens.Motion.contentDelay + step)
        let hiding = Animation.easeIn(duration: Tokens.Motion.hideFade)
        return self
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed ? 0 : Tokens.Motion.rowRise)
            .animation(revealed ? showing : hiding, value: revealed)
    }
}
