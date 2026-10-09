import AppKit
import SwiftUI

/// The system's own blurred material, as menus and popovers use it: it follows the appearance (dark stays dark, light
/// stays light) and does not shift with what is behind it, unlike Liquid Glass, which adapts to the backdrop's
/// brightness and so went pale over a white page. Forced active, so it looks the same whether or not the window has focus.
struct VisualEffectSurface: NSViewRepresentable {
    let material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}
