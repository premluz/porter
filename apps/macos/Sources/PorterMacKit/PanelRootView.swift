import PorterPanelModel
import SwiftUI

/// One surface that grows from its resting shape into the pane. The window stays one size for the whole move; this
/// view draws the shape at the size the spring gives for each frame, and fades the capsule's dots out and the pane's
/// content in as that progress passes fixed fractions. There is one shape throughout, so nothing depends on two views
/// being matched, and a move reversed halfway simply continues from where the shape is.
struct PanelRootView: View {
    let model: AppModel
    let presentation: PanelPresentation
    let expand: () -> Void
    let close: () -> Void
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        TimelineView(.animation(paused: !presentation.isAnimating)) { context in
            frame(at: context.date)
        }
    }

    @ViewBuilder
    private func frame(at date: Date) -> some View {
        let spec = presentation.shape(at: date)
        let progress = presentation.motion.progress(at: date)
        let content = presentation.motion.contentProgress(at: date)
        let anchor: Alignment = spec.edge == .right ? .trailing : .leading
        // Lets the animation probe see every frame; nothing happens unless it attached a recorder.
        let _ = presentation.recorder?(spec.rect)
        ZStack(alignment: .topLeading) {
            surface
            ZStack(alignment: anchor) {
                if progress < 0.999 {
                    CapsuleView(
                        model: model, expand: expand, reportDot: { id, frame in presentation.dotFrames[id] = frame },
                        hovered: presentation.hoveredDot
                    )
                    .opacity(PanelPhases.capsuleOpacity(progress: progress))
                    .allowsHitTesting(progress < 0.1)
                }
                // Always built, so opening only has to fade it in: creating it at the first frame of the move
                // cost about 75 ms and showed as a stutter. Hidden from touch and VoiceOver while collapsed.
                PaneView(model: model, presentation: presentation, progress: content, close: close)
                    .opacity(PanelPhases.paneOpacity(progress: content))
                    .allowsHitTesting(progress > 0.9)
                    .accessibilityHidden(progress < 0.5)
            }
            .frame(width: spec.rect.width, height: spec.rect.height, alignment: anchor)
            .offset(x: spec.rect.minX, y: spec.rect.minY)
            // The edge is drawn here: the system draws a glass edge only for an active window, and this one never is.
            PanelShape(spec: spec).stroke(Palette.glassEdge, lineWidth: Tokens.Size.edgeLine * 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipShape(PanelShape(spec: spec))
        .coordinateSpace(name: PanelPresentation.coordinateSpace)
    }

    /// The menu material, not Liquid Glass: glass lightens over a light page and darkens over a dark one, which is not
    /// what a native menu does. It fills the window and the shape cuts it out.
    @ViewBuilder
    private var surface: some View {
        if reduceTransparency {
            Palette.surfaceOpaque
        } else {
            VisualEffectSurface(material: Tokens.Surface.material)
        }
    }
}
