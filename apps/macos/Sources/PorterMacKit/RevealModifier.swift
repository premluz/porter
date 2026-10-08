import SwiftUI

extension View {
    /// A row's fade and lift follow the move's progress, each a little later than the one before, so
    /// content never shows on a shape that is still too narrow for it.
    func reveal(progress: Double, order: Int) -> some View {
        opacity(PanelPhases.rowOpacity(progress: progress, order: order))
            .offset(y: PanelPhases.rowOffset(progress: progress, order: order))
    }
}
