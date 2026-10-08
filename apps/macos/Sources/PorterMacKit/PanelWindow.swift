import AppKit

/// A borderless panel that never activates Porter, so showing it does not pull focus from the
/// app you are working in. It becomes the key window only while the pane is open, so typing works.
final class PanelWindow: NSPanel {
    var allowsKey = false
    var onCancel: () -> Void = {}

    override var canBecomeKey: Bool { allowsKey }
    override var canBecomeMain: Bool { false }

    init() {
        super.init(
            contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false
        )
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        // The system shadow is computed from the window's pixels once, not as the shape inside it animates,
        // so it would linger as a rectangle. The glass draws its own edge.
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        animationBehavior = .none
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel()
    }
}
