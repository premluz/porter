import PorterPanelModel
import SwiftUI

struct ItemRowView: View {
    let item: PanelItem
    let isSelected: Bool
    let activate: () -> Void

    var body: some View {
        Button(action: activate) {
            HStack(spacing: Tokens.Space.m) {
                StatusDotView(status: item.status)
                VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                    Text(item.title).font(.body).lineLimit(1)
                    Text(subtitle).font(.caption).foregroundStyle(Palette.textSecondary).lineLimit(1)
                }
                Spacer(minLength: Tokens.Space.s)
                trailingMarks
            }
            .padding(.horizontal, Tokens.Space.m)
            .frame(maxWidth: .infinity, minHeight: Tokens.Size.rowHeight, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Tokens.Space.m, style: .continuous).fill(isSelected ? Palette.selection : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(StatusPresentation.accessibilityLabel(for: item))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// The profile is always shown when titles repeat, so identical rows are never ambiguous to the eye.
    private var subtitle: String {
        var parts = [ProviderNames.display(item.provider)]
        if let alias = item.profileAlias { parts.append(alias) }
        parts.append(StatusPresentation.label(for: item.status))
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var trailingMarks: some View {
        if item.isAmbiguous {
            Label("\(item.routes.count) tabs", systemImage: "rectangle.on.rectangle")
                .labelStyle(.titleAndIcon).font(.caption).foregroundStyle(Palette.statusAttention)
        } else if item.availability == .unavailable(.closed) {
            Image(systemName: "xmark.rectangle").foregroundStyle(Palette.textSecondary)
        } else if item.availability == .unavailable(.sourceOffline) {
            Image(systemName: "bolt.horizontal.circle").foregroundStyle(Palette.textSecondary)
        }
        if item.pinned { Image(systemName: "pin.fill").font(.caption).foregroundStyle(Palette.textSecondary) }
    }
}
