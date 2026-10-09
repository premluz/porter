import PorterPanelModel
import SwiftUI

/// The expanded pane: search, pinned and open lists, recovery messages, and a hint line.
/// All keyboard handling is on the search field, which keeps focus so typing always works.
struct PaneView: View {
    @Bindable var model: AppModel
    let presentation: PanelPresentation
    /// How far the opening move has got, which paces the staggered fade-in of the content.
    let progress: Double
    let close: () -> Void
    @FocusState private var searchFocused: Bool
    @State private var isScrolling = false

    var body: some View {
        VStack(spacing: 0) {
            searchField.reveal(progress: progress, order: 0)
            if let shown = model.feedback { FeedbackView(model: model, shown: shown) }
            content
            footer.reveal(progress: progress, order: Tokens.Motion.staggerLimit)
        }
        // One backing under the whole pane, so the search field and the footer are the same tone as the list.
        .background(Palette.contentBacking)
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
        let split = model.snapshot.recentSplit()
        let groups = model.recentGroups
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    section("Pinned", model.snapshot.pinned, firstOrder: 1)
                    ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                        section(group.title, group.items, firstOrder: 1 + model.snapshot.pinned.count + groups[..<index].reduce(0) { $0 + $1.items.count })
                    }
                    olderGroup(split.older, firstOrder: 1 + model.snapshot.pinned.count + split.recent.count)
                }
                .padding(.horizontal, Tokens.Space.s)
            }
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(PanelPresentation.coordinateSpace)) } action: { presentation.listFrame = $0 }
            // The bar belongs to scrolling, not to layout: it stays hidden during resize and
            // appears only while a scroll is under way.
            .scrollIndicators(isScrolling ? .automatic : .hidden)
            .onScrollPhaseChange { _, phase in isScrolling = phase.isScrolling }
            .onChange(of: model.selection.selectedId) { _, id in
                if let id { proxy.scrollTo(id) }
            }
        }
    }

    /// Everything beyond the most recent few, folded away until asked for. A search shows it open.
    @ViewBuilder
    private func olderGroup(_ items: [PanelItem], firstOrder: Int) -> some View {
        if !items.isEmpty {
            Button { model.toggleOlder() } label: {
                HStack(spacing: Tokens.Space.xs) {
                    Image(systemName: model.showsOlder ? "chevron.down" : "chevron.right")
                    Text("Older (\(items.count))")
                    Spacer()
                }
                .font(.caption).textCase(.uppercase).foregroundStyle(Palette.textSecondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!model.query.trimmingCharacters(in: .whitespaces).isEmpty)
            .frame(height: Tokens.Size.sectionHeaderHeight, alignment: .bottom)
            .padding(.horizontal, Tokens.Space.m)
            .accessibilityLabel("Older conversations, \(items.count)")
            .accessibilityValue(model.showsOlder ? "expanded" : "collapsed")
            .reveal(progress: progress, order: firstOrder)
            if model.showsOlder { rows(items, firstOrder: firstOrder + 1) }
        }
    }

    @ViewBuilder
    private func section(_ title: String, _ items: [PanelItem], firstOrder: Int) -> some View {
        if !items.isEmpty {
            Text(title).font(.caption).textCase(.uppercase).foregroundStyle(Palette.textSecondary)
                .frame(height: Tokens.Size.sectionHeaderHeight, alignment: .bottom)
                .padding(.horizontal, Tokens.Space.m)
                .accessibilityAddTraits(.isHeader)
            rows(items, firstOrder: firstOrder)
        }
    }

    @ViewBuilder
    private func rows(_ items: [PanelItem], firstOrder: Int) -> some View {
        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
            ItemRowView(item: item, isSelected: item.id == model.selection.selectedId, isHovered: presentation.hoveredRow == item.id) {
                model.select(item)
                Task { await submit() }
            }
            .reveal(progress: progress, order: firstOrder + index)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(PanelPresentation.coordinateSpace)) } action: { presentation.rowFrames[item.id] = $0 }
            .onDisappear { presentation.rowFrames[item.id] = nil }
            .id(item.id)
            .contextMenu { menu(for: item) }
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
