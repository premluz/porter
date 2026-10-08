import PorterPanelModel
import SwiftUI

/// One glass surface that grows from the capsule into the pane. The window stays one size for the whole
/// move; this view draws the surface at the size the spring gives for each frame, and fades the capsule's
/// dots out and the pane's content in as that progress passes fixed fractions. There is one shape
/// throughout, so nothing depends on two views being matched, and a move reversed halfway simply
/// continues from where the surface is.
struct PanelRootView: View {
    let model: AppModel
    let presentation: PanelPresentation
    let expand: () -> Void
    let close: () -> Void
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        TimelineView(.animation(paused: !presentation.isMoving)) { context in
            frame(progress: presentation.motion.progress(at: context.date))
        }
    }

    @ViewBuilder
    private func frame(progress: Double) -> some View {
        let rect = PanelPhases.lerp(presentation.capsule, presentation.pane, progress)
        let shape = RoundedRectangle(cornerRadius: PanelPhases.cornerRadius(progress: progress), style: .continuous)
        let anchor: Alignment = presentation.edge == .right ? .trailing : .leading
        // Lets the animation probe see every frame; nothing happens unless it attached a recorder.
        let _ = presentation.recorder?(rect)
        ZStack(alignment: anchor) {
            if progress < 0.999 {
                CapsuleView(model: model, expand: expand)
                    .opacity(PanelPhases.capsuleOpacity(progress: progress))
                    .allowsHitTesting(progress < 0.1)
            }
            // Always built, so opening only has to fade it in: creating it at the first frame of the move
            // cost about 75 ms and showed as a stutter. Hidden from touch and VoiceOver while collapsed.
            PaneView(model: model, progress: progress, close: close)
                .opacity(PanelPhases.paneOpacity(progress: progress))
                .allowsHitTesting(progress > 0.9)
                .accessibilityHidden(progress < 0.5)
        }
        .frame(width: rect.width, height: rect.height, alignment: anchor)
        .background { surface(shape) }
        .clipShape(shape)
        .offset(x: rect.minX, y: rect.minY)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func surface(_ shape: RoundedRectangle) -> some View {
        if reduceTransparency {
            shape.fill(Palette.surfaceOpaque).overlay(shape.strokeBorder(Palette.borderSubtle))
        } else {
            shape.fill(.clear).glassEffect(.regular, in: shape)
        }
    }
}
