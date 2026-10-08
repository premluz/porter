import PorterPanelModel
import SwiftUI

/// One glass surface that morphs between the capsule and the pane. The window stays at its final
/// size for the whole move; the surface and its content animate inside it, so the system never
/// re-lays out a resizing window frame by frame.
struct PanelRootView: View {
    let model: AppModel
    let presentation: PanelPresentation
    let expand: () -> Void
    let close: () -> Void
    @Namespace private var surface
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let expanded = presentation.isExpanded
        GlassEffectContainer(spacing: 0) {
            ZStack(alignment: .topLeading) {
                if expanded {
                    shaped(PaneView(model: model, close: close), presentation.pane, Tokens.Size.paneCorner)
                } else {
                    shaped(CapsuleView(model: model, expand: expand), presentation.capsule, Tokens.Size.capsuleCorner)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private func shaped(_ content: some View, _ rect: CGRect, _ radius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if reduceTransparency {
            content
                .frame(width: rect.width, height: rect.height)
                .background(shape.fill(Palette.surfaceOpaque).overlay(shape.strokeBorder(Palette.borderSubtle)))
                .clipShape(shape)
                .matchedGeometryEffect(id: "surface", in: surface)
                .offset(x: rect.minX, y: rect.minY)
        } else {
            content
                .frame(width: rect.width, height: rect.height)
                .glassEffect(.regular, in: shape)
                .glassEffectID("surface", in: surface)
                .glassEffectTransition(.matchedGeometry)
                .clipShape(shape)
                .offset(x: rect.minX, y: rect.minY)
        }
    }
}
