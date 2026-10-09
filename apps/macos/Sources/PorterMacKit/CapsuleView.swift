import PorterPanelModel
import SwiftUI

/// The collapsed edge capsule: a few direct shortcuts and a control to open the pane.
struct CapsuleView: View {
    let model: AppModel
    let expand: () -> Void
    /// Tells the panel where a dot is, or that it has gone (nil), so hovering it can show its label.
    let reportDot: (String, CGRect?) -> Void
    /// The dot or the open button under the pointer.
    let hovered: String?

    private var dots: [PanelItem] { Array(model.items.prefix(Tokens.Capsule.maximumDots)) }
    private var overflow: Int { max(model.items.count - Tokens.Capsule.maximumDots, 0) }

    var body: some View {
        VStack(spacing: Tokens.Space.xs) {
            Button(action: expand) {
                Image(systemName: "chevron.left.2").frame(width: Tokens.Size.expandButton, height: Tokens.Size.expandButton)
                    .foregroundStyle(hovered == PanelPresentation.openButtonId ? Palette.textPrimary : Palette.textSecondary)
            }
            .buttonStyle(.plain)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(PanelPresentation.coordinateSpace)) } action: { reportDot(PanelPresentation.openButtonId, $0) }
            .padding(.bottom, Tokens.Space.s)
            .help("Open Porter")
            .accessibilityLabel("Open Porter")
            ForEach(dots) { item in
                Button { Task { await shortcut(item) } } label: {
                    StatusDotView(status: item.status)
                        .frame(width: Tokens.Size.capsuleDot, height: Tokens.Size.capsuleDot)
                        .background(Circle().fill(hovered == item.id ? Palette.dotHover : Palette.contentBacking))
                        .scaleEffect(hovered == item.id ? Tokens.Size.dotHoverScale : 1)
                        .animation(.easeOut(duration: Tokens.Motion.dotHover), value: hovered)
                }
                .buttonStyle(.plain)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(PanelPresentation.coordinateSpace)) } action: { reportDot(item.id, $0) }
                .onDisappear { reportDot(item.id, nil) }
                .accessibilityLabel(StatusPresentation.accessibilityLabel(for: item))
            }
            if overflow > 0 {
                Text("+\(overflow)").font(.caption2).foregroundStyle(Palette.textSecondary)
                    .frame(height: Tokens.Size.capsuleDot)
                    .accessibilityLabel("\(overflow) more conversations")
            }
        }
        .frame(width: Tokens.Size.capsuleWidth)
        .padding(.vertical, Tokens.Space.m)
    }

    /// A dot opens its chat directly when that is unambiguous; otherwise it opens the pane on it.
    private func shortcut(_ item: PanelItem) async {
        model.select(item)
        if item.routes.count == 1 {
            await model.activateSelected()
        } else {
            expand()
        }
    }
}
