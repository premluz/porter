import PorterPanelModel
import SwiftUI

struct PhoneRow: View {
    let item: PanelItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(tint).frame(width: 24).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).foregroundStyle(.primary)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if item.pinned { Image(systemName: "pin.fill").font(.caption).foregroundStyle(.secondary) }
        }
        .frame(minHeight: 44)
    }

    /// Profile is always shown, because identical titles are common across accounts.
    private var subtitle: String {
        var parts = [ProviderNames.display(item.provider)]
        if let alias = item.profileAlias { parts.append(alias) }
        parts.append(StatusPresentation.label(for: item.status))
        return parts.joined(separator: " · ")
    }

    /// Shape as well as colour: a dashed ring means "not live".
    private var symbol: String {
        guard item.status.freshness == .fresh else { return "circle.dashed" }
        switch item.status.display {
        case .needsUser: return "exclamationmark.circle.fill"
        case .working: return "circle.dotted"
        case .newResponse: return "circle.fill"
        case .idle: return "circle.fill"
        case .unknown: return "circle"
        }
    }

    private var tint: Color {
        guard item.status.freshness == .fresh else { return .secondary }
        switch item.status.display {
        case .needsUser: return .orange
        case .working: return .green
        case .newResponse: return .accentColor
        case .idle, .unknown: return .secondary
        }
    }
}
