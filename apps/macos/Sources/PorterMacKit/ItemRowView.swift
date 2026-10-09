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
                    detailLine
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

    /// The project (a pill), the assistant's logo and the status. A browser chat has no project, so its profile follows
    /// the status as plain text, and it is always shown there so identical titles are never ambiguous to the eye.
    private var detailLine: some View {
        HStack(spacing: Tokens.Space.s) {
            if let project = item.projectName { PillView(text: project) }
            ProviderLogoView(provider: item.provider)
            Text(statusText).font(.caption).foregroundStyle(Palette.textSecondary).lineLimit(1)
        }
    }

    private var statusText: String {
        let status = StatusPresentation.label(for: item.status)
        guard item.projectName == nil, let alias = item.profileAlias else { return status }
        return "\(status) · \(alias)"
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
