import PorterPanelModel
import SwiftUI

/// Status as shape plus colour, never colour alone. Only a fresh working state moves.
struct StatusDotView: View {
    let status: ItemStatus
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    var body: some View {
        mark
            .frame(width: Tokens.Size.statusDot, height: Tokens.Size.statusDot)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var mark: some View {
        if status.freshness != .fresh {
            Circle().strokeBorder(Palette.textSecondary, style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
        } else {
            switch status.display {
            case .working:
                Circle().strokeBorder(Palette.statusWorking, lineWidth: 2)
                    .scaleEffect(pulsing && !reduceMotion ? 1.15 : 1)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 1).repeatForever(), value: pulsing)
                    .onAppear { pulsing = true }
            case .needsUser:
                Image(systemName: "exclamationmark.circle.fill").resizable().foregroundStyle(Palette.statusAttention)
            case .newResponse:
                Circle().fill(Palette.statusUnread)
            case .idle:
                Circle().fill(Palette.textSecondary)
            case .unknown:
                Circle().strokeBorder(Palette.textSecondary, lineWidth: 1)
            }
        }
    }
}
