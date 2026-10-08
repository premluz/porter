import PorterPanelModel
import SwiftUI

/// The expanded pane: search, pinned and open lists, recovery messages, and a hint line.
/// All keyboard handling is on the search field, which keeps focus so typing always works.
struct PaneView: View {
    @Bindable var model: AppModel
    let close: () -> Void
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchField
            if let shown = model.feedback { FeedbackView(model: model, shown: shown) }
            content
            footer
        }
        .frame(width: Tokens.Size.paneWidth)
        .onChange(of: model.focusRequest) { searchFocused = true }
        .onAppear { searchFocused = true }
    }

    private var searchField: some View {
        HStack(spacing: Tokens.Space.s) {
            Image(systemName: "magnifyingglass").foregroundStyle(Palette.textSecondary)
            TextField("Search conversations", text: $model.query)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .onSubmit { Task { await submit() } }
                .onKeyPress(phases: [.down, .repeat]) { press in handle(press) }
                .accessibilityLabel("Search conversations")
        }
        .padding(.horizontal, Tokens.Space.m)
        .frame(height: Tokens.Size.headerHeight)
    }

    @ViewBuilder
    private var content: some View {
        if let review = model.packetReview {
            PacketReviewView(model: model, review: review)
        } else if let choice = model.routeChoice {
            RouteChoiceView(model: model, choice: choice)
        } else if let empty = model.snapshot.emptyState {
            EmptyStateView(state: empty)
        } else {
            list
        }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    section("Pinned", model.snapshot.pinned)
                    section("Open", model.snapshot.open)
                }
                .padding(.horizontal, Tokens.Space.s)
                .background(Palette.contentBacking)
            }
            .onChange(of: model.selection.selectedId) { _, id in
                if let id { proxy.scrollTo(id) }
            }
        }
    }

    @ViewBuilder
    private func section(_ title: String, _ items: [PanelItem]) -> some View {
        if !items.isEmpty {
            Text(title).font(.caption).textCase(.uppercase).foregroundStyle(Palette.textSecondary)
                .frame(height: Tokens.Size.sectionHeaderHeight, alignment: .bottom)
                .padding(.horizontal, Tokens.Space.m)
                .accessibilityAddTraits(.isHeader)
            ForEach(items) { item in
                ItemRowView(item: item, isSelected: item.id == model.selection.selectedId) {
                    model.select(item)
                    Task { await submit() }
                }
                .id(item.id)
                .contextMenu { menu(for: item) }
            }
        }
    }

    @ViewBuilder
    private func menu(for item: PanelItem) -> some View {
        Button(item.pinned ? "Unpin" : "Pin") { Task { await model.togglePin(item) } }
        Button(item.hidden ? "Show again" : "Hide") { Task { await model.toggleHidden(item) } }
        if let link = item.desktopLink {
            Button("Open in Claude app") { model.openInDesktopApp(link.url) }
        }
    }

    private var footer: some View {
        HStack {
            Text(model.problem ?? model.notice ?? "↩ open   ⌘P pin   ⌘O Claude app   ⌘⌫ hide   esc close")
                .font(.caption).lineLimit(3)
                .foregroundStyle(model.problem == nil ? Palette.textSecondary : Palette.statusAttention)
            Spacer()
            if !model.snapshot.hidden.isEmpty {
                Button(model.showHidden ? "Hide hidden" : "Show \(model.snapshot.hidden.count) hidden") {
                    model.toggleShowHidden()
                }
                .buttonStyle(.link).font(.caption)
            }
        }
        .padding(.horizontal, Tokens.Space.m)
        .frame(minHeight: Tokens.Size.footerHeight)
    }

    private func submit() async {
        if model.routeChoice != nil { await model.confirmRouteChoice() } else { await model.activateSelected() }
    }
}
