import AppKit
import PorterPanelModel
import SwiftUI

/// A small window that shows what a dot in the collapsed capsule stands for. It never takes the pointer or focus, so it
/// cannot get in the way of the capsule it describes.
final class TooltipPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// The label's content: the same title and detail line a row has, so a dot says what its row would.
struct TooltipView: View {
    let item: PanelItem

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            Text(item.title).font(.body).lineLimit(2)
            ItemDetailLine(item: item)
        }
        .padding(.horizontal, Tokens.Space.m).padding(.vertical, Tokens.Space.s)
        .frame(maxWidth: Tokens.Size.tooltipMaximumWidth, alignment: .leading)
        .fixedSize(horizontal: true, vertical: true)
        .background {
            let shape = RoundedRectangle(cornerRadius: Tokens.Space.m, style: .continuous)
            shape.fill(.clear).glassEffect(.regular, in: shape)
                .overlay(shape.strokeBorder(Palette.glassEdge, lineWidth: Tokens.Size.edgeLine))
        }
    }
}

/// Shows the label after the pointer has rested on a dot for a moment, and takes it away when it leaves.
@MainActor
final class TooltipController {
    private let panel = TooltipPanel()
    private let host = NSHostingView(rootView: TooltipPlaceholder())
    private var pending: Task<Void, Never>?
    private(set) var shownId: String?

    init() {
        panel.contentView = host
    }

    func show(_ item: PanelItem, anchor: CGRect, window: CGRect, edge: PanelEdge, visible: CGRect) {
        guard item.id != shownId else { return }
        pending?.cancel()
        shownId = item.id
        pending = Task { [weak self] in
            try? await Task.sleep(for: Tokens.Motion.tooltipDelay)
            guard !Task.isCancelled, let self else { return }
            let content = NSHostingView(rootView: TooltipView(item: item))
            let size = content.fittingSize
            panel.contentView = content
            panel.setFrame(CapsuleHover.tooltipFrame(anchor: anchor, size: size, window: window, edge: edge, visible: visible), display: true)
            panel.orderFrontRegardless()
        }
    }

    func hide() {
        pending?.cancel()
        pending = nil
        shownId = nil
        panel.orderOut(nil)
    }
}

private struct TooltipPlaceholder: View {
    var body: some View { EmptyView() }
}
