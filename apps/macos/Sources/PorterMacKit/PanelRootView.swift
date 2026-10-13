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
        let restAmounts = PanelPhases.restBlend(
            fromTab: presentation.restFrom.kind == .tab, toTab: presentation.rest.kind == .tab,
            progress: presentation.restMotion.progress(at: date)
        )
        let notch = PanelPhases.notch(tab: restAmounts.tab, progress: progress)
        // Lets the animation probe see every frame; nothing happens unless it attached a recorder.
        let _ = presentation.recorder?(spec.rect)
        ZStack(alignment: .topLeading) {
            surface
            Palette.dockedSurface.opacity(notch)
            layers(spec: spec, progress: progress, content: content, rest: restAmounts)
                .offset(x: spec.rect.minX, y: spec.rect.minY)
            // The edge is drawn here: the system draws a glass edge only for an active window, and this one never is.
            // A docked tab has none, like a cut-out in the screen.
            PanelShape(spec: spec).stroke(Palette.glassEdge.opacity(1 - notch), lineWidth: Tokens.Size.edgeLine * 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipShape(PanelShape(spec: spec), style: FillStyle(eoFill: true))
        .coordinateSpace(name: PanelPresentation.coordinateSpace)
    }

    /// The resting content (capsule or tab) and the pane, stacked at the shape's size and fading into one another.
    private func layers(spec: ShapeSpec, progress: Double, content: Double, rest: (tab: Double, capsule: Double)) -> some View {
        let anchor: Alignment = spec.edge == .right ? .trailing : .leading
        return ZStack(alignment: anchor) {
            if rest.capsule > 0.001, progress < 0.999 {
                CapsuleView(
                    model: model, orientation: presentation.capsuleOrientation, opensFrom: spec.edge, expand: expand,
                    reportDot: { id, frame in presentation.dotFrames[id] = frame }, hovered: presentation.hoveredDot,
                    pressAllowed: { Date() >= presentation.clicksIgnoredUntil }, drag: { presentation.onDrag?($0) }
                )
                .opacity(PanelPhases.capsuleOpacity(progress: progress) * rest.capsule)
                .allowsHitTesting(progress < 0.1 && rest.capsule > 0.5)
            }
            if rest.tab > 0.001, progress < 0.999 {
                TabView(
                    status: model.tabStatus, speaking: model.isSpeaking, listening: model.isListening,
                    opensFrom: spec.edge, expand: expand, pressAllowed: { Date() >= presentation.clicksIgnoredUntil }
                )
                .environment(\.colorScheme, .dark)
                // The stack is as wide as the pane, so without its own size the face would centre on the pane.
                .frame(width: spec.rect.width, height: spec.rect.height)
                .opacity(PanelPhases.capsuleOpacity(progress: progress) * rest.tab)
                .allowsHitTesting(progress < 0.1 && rest.tab > 0.5)
            }
            // Always built, so opening only has to fade it in: creating it at the first frame of the move
            // cost about 75 ms and showed as a stutter. Hidden from touch and VoiceOver while collapsed.
            PaneView(model: model, presentation: presentation, progress: content, close: close)
                .opacity(PanelPhases.paneOpacity(progress: content))
                .allowsHitTesting(progress > 0.9)
                .accessibilityHidden(progress < 0.5)
        }
        .frame(width: spec.rect.width, height: spec.rect.height, alignment: anchor)
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
