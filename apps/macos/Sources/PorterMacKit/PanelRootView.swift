import PorterPanelModel
import SwiftUI

/// One continuous silhouette. Corner radius and which content shows follow the window's live
/// width, so the shape and its content stay in step with the window frame animation, and an
/// interrupted animation simply continues from wherever the width currently is.
struct PanelRootView: View {
    let model: AppModel
    let edge: PanelEdge
    let expand: () -> Void
    let close: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let progress = EdgeGeometry.progress(width: proxy.size.width)
            let radius = EdgeGeometry.cornerRadius(progress: progress)
            ZStack(alignment: edge == .right ? .trailing : .leading) {
                CapsuleView(model: model, expand: expand)
                    .opacity(EdgeGeometry.capsuleContentOpacity(progress: progress))
                    .allowsHitTesting(progress < 0.1)
                PaneView(model: model, close: close)
                    .opacity(EdgeGeometry.paneContentOpacity(progress: progress))
                    .allowsHitTesting(progress > 0.9)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: edge == .right ? .trailing : .leading)
            .background { GlassBackground(cornerRadius: radius) }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
    }
}
