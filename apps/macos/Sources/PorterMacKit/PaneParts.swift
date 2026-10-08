import PorterPanelModel
import SwiftUI

struct EmptyStateView: View {
    let state: EmptyState

    var body: some View {
        VStack(spacing: Tokens.Space.s) {
            Image(systemName: symbol).font(.title2).foregroundStyle(Palette.textSecondary)
            Text(title).font(.headline)
            Text(detail).font(.callout).foregroundStyle(Palette.textSecondary).multilineTextAlignment(.center)
        }
        .padding(Tokens.Space.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch state {
        case .noSources: "bolt.horizontal.circle"
        case .noConversations: "bubble.left.and.bubble.right"
        case .noMatches: "magnifyingglass"
        }
    }

    private var title: String {
        switch state {
        case .noSources: "No browser connected"
        case .noConversations: "Nothing open yet"
        case .noMatches(let query): "No match for “\(query)”"
        }
    }

    private var detail: String {
        switch state {
        case .noSources: "Open Chrome with the Porter extension installed, then allow access to claude.ai in its options."
        case .noConversations: "Open a Claude chat in a connected browser profile and it will appear here."
        case .noMatches: "Try fewer words, or clear the search."
        }
    }
}

/// Several tabs show one chat: the user picks. Porter never chooses between them.
struct RouteChoiceView: View {
    let model: AppModel
    let choice: RouteChoice

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            Text("“\(choice.item.title)” is open in \(choice.item.routes.count) tabs").font(.headline)
            Text("Choose which one to open.").font(.callout).foregroundStyle(Palette.textSecondary)
            ForEach(Array(choice.item.routes.enumerated()), id: \.element.id) { index, route in
                Button { Task { await model.activate(choice.item, route) } } label: {
                    Text("Tab \(index + 1)" + (route.windowId.map { " · window \($0)" } ?? ""))
                        .frame(maxWidth: .infinity, minHeight: Tokens.Size.rowHeight / 1.5, alignment: .leading)
                        .padding(.horizontal, Tokens.Space.m)
                        .background(RoundedRectangle(cornerRadius: Tokens.Space.m, style: .continuous)
                            .fill(index == choice.index ? Palette.selection : .clear))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(Tokens.Space.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// A failed open: what happened, and concrete next steps. Nothing here acts by itself.
struct FeedbackView: View {
    let model: AppModel
    let shown: ShownFeedback

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            Text(shown.feedback.title).font(.headline)
            Text(shown.feedback.detail).font(.callout).foregroundStyle(Palette.textSecondary)
            HStack {
                ForEach(Array(shown.feedback.recovery.enumerated()), id: \.offset) { _, action in
                    if let label = label(for: action) {
                        Button(label) { Task { await model.perform(action, for: shown.item) } }
                    }
                }
            }
            .padding(.top, Tokens.Space.xs)
        }
        .padding(Tokens.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.contentBacking)
        .accessibilityElement(children: .contain)
    }

    private func label(for action: RecoveryAction) -> String? {
        switch action {
        case .tryAgain: "Try again"
        case .refreshList: "Refresh"
        case .reconnectSource: "Open Chrome"
        case .allowSiteAccess: nil
        case .openInDesktopApp: "Open in Claude app"
        case .openSavedLinkInDefaultBrowser: "Open saved link in default browser…"
        case .removeShortcut: "Remove shortcut"
        }
    }
}
