import PorterPanelModel
import SwiftUI

/// The collapsed edge capsule: a few direct shortcuts and a control to open the pane.
struct CapsuleView: View {
    let model: AppModel
    let expand: () -> Void

    private var dots: [PanelItem] { Array(model.items.prefix(Tokens.Capsule.maximumDots)) }
    private var overflow: Int { max(model.items.count - Tokens.Capsule.maximumDots, 0) }

    var body: some View {
        VStack(spacing: Tokens.Space.xs) {
            Button(action: expand) {
                Image(systemName: "chevron.left.2").frame(width: Tokens.Size.expandButton, height: Tokens.Size.expandButton)
            }
            .buttonStyle(.plain)
            .padding(.bottom, Tokens.Space.s)
            .help("Open Porter")
            .accessibilityLabel("Open Porter")
            ForEach(dots) { item in
                Button { Task { await shortcut(item) } } label: {
                    StatusDotView(status: item.status)
                        .frame(width: Tokens.Size.capsuleDot, height: Tokens.Size.capsuleDot)
                        .background(Circle().fill(Palette.contentBacking))
                }
                .buttonStyle(.plain)
                .help(StatusPresentation.accessibilityLabel(for: item))
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
