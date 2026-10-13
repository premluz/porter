import PorterPanelModel
import SwiftUI

/// The collapsed capsule, upright or lying down: a control to open the pane, then a few direct shortcuts. It can be
/// dragged anywhere; a drag never presses a dot.
struct CapsuleView: View {
    let model: AppModel
    let orientation: PanelOrientation
    /// The screen edge the pane opens from, which decides which way the open control points.
    let opensFrom: PanelEdge
    let expand: () -> Void
    /// Tells the panel where a dot is, or that it has gone (nil), so hovering it can show its label.
    let reportDot: (String, CGRect?) -> Void
    /// The dot or the open button under the pointer.
    let hovered: String?
    /// False for a moment after a drag, so letting go over a dot does not press it.
    let pressAllowed: () -> Bool
    let drag: (DragPhase) -> Void

    private var dots: [PanelItem] { Array(model.items.prefix(Tokens.Capsule.maximumDots)) }
    private var overflow: Int { max(model.items.count - Tokens.Capsule.maximumDots, 0) }

    var body: some View {
        axis {
            openButton
            ForEach(dots) { item in dot(item) }
            if overflow > 0 {
                Text("+\(overflow)").font(.caption2).foregroundStyle(Palette.textSecondary)
                    .frame(width: orientation == .horizontal ? nil : nil, height: Tokens.Size.capsuleDot)
                    .accessibilityLabel("\(overflow) more conversations")
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: Tokens.Size.dragStart, coordinateSpace: .global)
                .onChanged { _ in drag(.changed) }
                .onEnded { _ in drag(.ended) }
        )
    }

    @ViewBuilder
    private func axis<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        switch orientation {
        case .vertical:
            VStack(spacing: Tokens.Space.xs, content: content).frame(width: Tokens.Size.capsuleWidth).padding(.vertical, Tokens.Space.m)
        case .horizontal:
            HStack(spacing: Tokens.Space.xs, content: content).frame(height: Tokens.Size.capsuleWidth).padding(.horizontal, Tokens.Space.m)
        }
    }

    private var openButton: some View {
        Button { if pressAllowed() { expand() } } label: {
            Image(systemName: opensFrom == .right ? "chevron.left.2" : "chevron.right.2")
                .frame(width: Tokens.Size.expandButton, height: Tokens.Size.expandButton)
                .foregroundStyle(hovered == PanelPresentation.openButtonId ? Palette.textPrimary : Palette.textSecondary)
        }
        .buttonStyle(.plain)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(PanelPresentation.coordinateSpace)) } action: { reportDot(PanelPresentation.openButtonId, $0) }
        .padding(orientation == .vertical ? .bottom : .trailing, Tokens.Space.s)
        .accessibilityLabel("Open Porter")
    }

    private func dot(_ item: PanelItem) -> some View {
        Button { if pressAllowed() { Task { await shortcut(item) } } } label: {
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

/// The docked tab: one face for the chats together, orange when a question is waiting, green when work is in progress,
/// gray otherwise.
struct TabView: View {
    let status: ItemStatus?
    var speaking = false
    var listening = false
    let opensFrom: PanelEdge
    let expand: () -> Void
    let pressAllowed: () -> Bool

    var body: some View {
        Button { if pressAllowed() { expand() } } label: {
            MascotView(tone: MascotTone(status), opensFrom: opensFrom, speaking: speaking, listening: listening)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var label: String {
        if listening { return "Open Porter, listening for a voice command" }
        if speaking { return "Open Porter, speaking an announcement" }
        return switch status?.display {
        case .needsUser: "Open Porter, a chat needs you"
        case .working: "Open Porter, a chat is working"
        default: "Open Porter"
        }
    }
}
