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
            VisualEffectSurface(material: Tokens.Surface.material)
                .clipShape(shape)
                .overlay(shape.strokeBorder(Palette.glassEdge, lineWidth: Tokens.Size.edgeLine))
        }
    }
}

/// Shows the label beside the dot under the pointer. It appears at once, slides from one dot to the next without ever
/// leaving, and eases away only when the pointer leaves the last dot or the capsule.
@MainActor
final class TooltipController {
    private let panel = TooltipPanel()
    private var generation = 0
    private(set) var shownId: String?

    private var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    func show(_ item: PanelItem, anchor: CGRect, window: CGRect, edge: PanelEdge, visible: CGRect) {
        guard item.id != shownId else { return }
        generation += 1
        let wasShowing = shownId != nil
        shownId = item.id
        let content = NSHostingView(rootView: TooltipView(item: item))
        let target = CapsuleHover.tooltipFrame(anchor: anchor, size: content.fittingSize, window: window, edge: edge, visible: visible)
        panel.contentView = content
        if wasShowing {
            move(to: target)
        } else {
            appear(at: target, edge: edge)
        }
    }

    func hide() {
        guard shownId != nil else { return }
        generation += 1
        let mine = generation
        shownId = nil
        NSAnimationContext.runAnimationGroup { context in
            context.duration = reduceMotion ? Tokens.Motion.tooltipFade : Tokens.Motion.tooltipOut
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            // A label shown again in the meantime owns the window now.
            Task { @MainActor in if self?.generation == mine { self?.panel.orderOut(nil) } }
        }
    }

    /// Comes in from just inside the capsule's edge, slightly smaller, so it seems to grow out of the dot.
    private func appear(at target: CGRect, edge: PanelEdge) {
        var start = target
        if !reduceMotion {
            let shrink = Tokens.Motion.tooltipEntryScale
            start.size = CGSize(width: target.width * shrink, height: target.height * shrink)
            start.origin.y = target.midY - start.height / 2
            start.origin.x = edge == .right ? target.maxX - start.width : target.minX
        }
        panel.setFrame(start, display: true)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = reduceMotion ? Tokens.Motion.tooltipFade : Tokens.Motion.tooltipIn
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(target, display: true)
            panel.animator().alphaValue = 1
        }
    }

    /// Moving to the next dot keeps the window and glides it, so a sweep along the dots reads as one label following.
    private func move(to target: CGRect) {
        panel.alphaValue = 1
        guard !reduceMotion else {
            panel.setFrame(target, display: true)
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Tokens.Motion.tooltipGlide
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(target, display: true)
        }
    }
}
