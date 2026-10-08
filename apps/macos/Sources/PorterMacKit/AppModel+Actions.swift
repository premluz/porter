import ConversationCore
import Foundation
import PorterPanelModel
import PorterStore

/// Things the model asks the app to do that touch the outside world, so tests can observe them.
@MainActor
public protocol RecoveryPerformer: Sendable {
    func openInDefaultBrowser(_ url: URL)
    /// Asks a desktop app to show a chat through its documented link.
    func openInDesktopApp(_ url: URL)
    /// Puts text on the pasteboard. Only ever called on an explicit user action.
    func copyToPasteboard(_ text: String)
    func launchBrowser()
}

extension AppModel {
    public func activateSelected() async {
        switch selection.action(in: items) {
        case .activate(let item, let route): await activate(item, route)
        case .chooseRoute(let item): routeChoice = RouteChoice(item: item, index: 0)
        case .showRecovery(let item): showRecovery(for: item)
        case .nothing: break
        }
    }

    public func confirmRouteChoice() async {
        guard let choice = routeChoice, choice.item.routes.indices.contains(choice.index) else { return }
        routeChoice = nil
        await activate(choice.item, choice.item.routes[choice.index])
    }

    public func activate(_ item: PanelItem, _ route: PanelRoute) async {
        guard !isBusy else { return }
        isBusy = true
        let report = await source.activate(destinationId: route.destinationId, revision: route.revision)
        isBusy = false
        let result = ActivationFeedbackBuilder.feedback(for: report.outcome, item: item)
        if result.dismissesPane {
            feedback = nil
            onHandoff()
        } else {
            feedback = ShownFeedback(item: item, feedback: result)
            await refresh()
        }
    }

    public func perform(_ action: RecoveryAction, for item: PanelItem) async {
        switch action {
        case .tryAgain: await activateSelected()
        case .refreshList: feedback = nil; await refresh()
        case .reconnectSource: performer.launchBrowser()
        case .allowSiteAccess: break
        case .removeShortcut: await unpin(item)
        case .openInDesktopApp(let text): openInDesktopApp(text)
        case .openSavedLinkInDefaultBrowser(let text):
            guard let url = URL(string: text), url.scheme == "https" else {
                problem = "The saved link is not a secure web address, so it was not opened."
                return
            }
            performer.openInDefaultBrowser(url)
        }
    }

    /// Only the exact documented chat link is ever handed to the system, and only on a user action.
    public func openInDesktopApp(_ text: String) {
        guard DesktopLinks.isAllowedClaudeChatLink(text), let url = URL(string: text) else {
            problem = "That is not a link Porter is allowed to open in the desktop app."
            return
        }
        performer.openInDesktopApp(url)
        notice = "Asked the Claude app to show it. Porter can't see which account the app is signed into; if the chat isn't there, the app shows your recent chats."
    }

    public func openSelectedInDesktopApp() {
        guard let link = selectedItem?.desktopLink else {
            notice = "There is no desktop app link for this conversation."
            return
        }
        openInDesktopApp(link.url)
    }

    public func togglePin(_ item: PanelItem) async {
        if item.pinned { await unpin(item) } else { await mutate("pin") { (store, now) async throws(StoreError) in try await store.pin(item.snapshot, at: now) } }
    }

    public func unpin(_ item: PanelItem) async {
        await mutate("unpin") { (store, now) async throws(StoreError) in try await store.unpin(item.key, at: now) }
    }

    public func toggleHidden(_ item: PanelItem) async {
        if item.hidden {
            await mutate("unhide") { (store, now) async throws(StoreError) in try await store.unhide(item.key, at: now) }
        } else {
            await mutate("hide") { (store, now) async throws(StoreError) in try await store.hide(item.snapshot, at: now) }
        }
    }

    private func showRecovery(for item: PanelItem) {
        let outcome: ActivationOutcome = item.availability == .unavailable(.sourceOffline) ? .connectorOffline : .targetGone
        feedback = ShownFeedback(item: item, feedback: ActivationFeedbackBuilder.feedback(for: outcome, item: item))
    }

    private func mutate(
        _ name: String, _ change: (PreferenceStore, Date) async throws(StoreError) -> Void
    ) async {
        do {
            try await change(store, clock())
            await refresh()
        } catch {
            problem = "Could not \(name): \(error)"
        }
    }
}
