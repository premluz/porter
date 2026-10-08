import PorterPanelModel
import SwiftUI

struct PhoneListView: View {
    @Bindable var model: PhoneModel
    @State private var selected: PanelItem?

    var body: some View {
        NavigationStack {
            List {
                if model.isSampleData { sampleBanner }
                if let problem = model.problem { Text(problem).foregroundStyle(.red) }
                section("Pinned", model.snapshot.pinned)
                section("Open on your Mac", model.snapshot.open)
                if let empty = model.snapshot.emptyState { emptyView(empty) }
            }
            .navigationTitle("Porter")
            .searchable(text: $model.query, prompt: "Search conversations")
            .sheet(item: $selected) { item in PhoneDetailView(item: item, isSample: model.isSampleData) }
        }
    }

    private var sampleBanner: some View {
        Label("Sample data. Syncing from your Mac is not set up yet.", systemImage: "info.circle")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func section(_ title: String, _ items: [PanelItem]) -> some View {
        if !items.isEmpty {
            Section(title) {
                ForEach(items) { item in
                    Button { selected = item } label: { PhoneRow(item: item).contentShape(Rectangle()) }
                        .buttonStyle(.plain)
                        .accessibilityLabel(StatusPresentation.accessibilityLabel(for: item))
                }
            }
        }
    }

    @ViewBuilder
    private func emptyView(_ state: EmptyState) -> some View {
        switch state {
        case .noSources: ContentUnavailableView("Nothing synced yet", systemImage: "icloud.slash",
            description: Text("Turn on syncing in Porter on your Mac."))
        case .noConversations: ContentUnavailableView("No conversations", systemImage: "bubble.left.and.bubble.right")
        case .noMatches(let query): ContentUnavailableView.search(text: query)
        }
    }
}
