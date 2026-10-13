import BridgeTransport
import ConversationCore
import Foundation
import Observation
import PorterPanelModel
import PorterStore

/// A failed open with the item it was for, so recovery buttons act on the right thing.
public struct ShownFeedback: Equatable, Sendable {
    public let item: PanelItem
    public let feedback: ActivationFeedback
}

public struct RouteChoice: Equatable, Sendable {
    public let item: PanelItem
    public var index: Int
}

/// Everything the panel shows and does, with no AppKit in it, so behavior is tested without a screen.
@MainActor
@Observable
public final class AppModel {
    public internal(set) var snapshot: PanelSnapshot
    public internal(set) var selection = PanelSelection()
    public internal(set) var feedback: ShownFeedback?
    public internal(set) var routeChoice: RouteChoice?
    public internal(set) var problem: String?
    /// A plain, non-error remark after an action Porter cannot verify, such as a desktop app link.
    public internal(set) var notice: String?
    /// A packet being reviewed. Held in memory only, and dropped when review ends.
    public internal(set) var packetReview: PacketReview?
    /// Which open chat the packet is meant for; chosen by the user unless exactly one chat matches.
    public internal(set) var packetDestinationId: String?
    public internal(set) var isBusy = false
    /// Increments whenever the search field should take focus.
    public private(set) var focusRequest = 0
    public private(set) var showHidden = false
    /// Whether the folded group of older conversations is open; a search always shows every match.
    public private(set) var olderExpanded = false
    public var query = "" {
        didSet { if query != oldValue { queryChanged() } }
    }

    /// Called after a successful handoff, so the window can collapse.
    public var onHandoff: () -> Void = {}
    /// Called when the list changed in a way that affects the capsule's size.
    public var onContentChanged: () -> Void = {}

    let source: any DestinationSource
    let store: PreferenceStore
    let performer: any RecoveryPerformer
    let clock: @Sendable () -> Date
    var listing = RegistryListing(connectors: [], rows: [])
    var records: [PreferenceRecord] = []
    var frozenOrder: [String]?
    /// Posts a notice when a chat starts waiting on the person; nil in tests and in sample-data mode.
    public var notifier: (any NeedsYouNotifying)?
    public var completionAnnouncer: (any Announcing)?
    public var speechAnnouncer: SpeechAnnouncer?
    public var voiceSettings: VoiceSettings?
    public internal(set) var isSpeaking = false
    public internal(set) var isListening = false
    public internal(set) var observedItems: [PanelItem] = []
    public internal(set) var lastCompletion: Completion?
    var completionDetector = CompletionDetector()
    var completionCoalescer = CompletionCoalescer()
    var completionTimer: Task<Void, Never>?
    /// The chats already announced as waiting, so a refresh never announces the same one twice.
    var announcedWaiting: Set<String> = []
    var isPaneVisible = false

    public init(
        source: any DestinationSource, store: PreferenceStore, performer: any RecoveryPerformer,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.source = source
        self.store = store
        self.performer = performer
        self.clock = clock
        snapshot = PanelBuilder.build(PanelInputs(rows: [], connectors: [], records: [], now: clock()))
    }

    public var showsOlder: Bool { olderExpanded || !query.trimmingCharacters(in: .whitespaces).isEmpty }

    /// The most recent open conversations under the day each was last used (Today, Yesterday, 2 days ago, …).
    public var recentGroups: [ItemGroup] { DayGrouping.groups(snapshot.recentSplit().recent, now: clock()) }

    /// What the docked tab shows, as one mark for all the chats together: a question to answer outranks work in
    /// progress. With neither, nothing: the tab shows its face, and claims nothing about the rest.
    public var tabStatus: ItemStatus? {
        let fresh = items.map(\.status).filter { $0.freshness == .fresh }
        return fresh.first { $0.display == .needsUser } ?? fresh.first { $0.display == .working }
    }

    public var items: [PanelItem] { snapshot.navigable(showingOlder: showsOlder) }

    public var selectedItem: PanelItem? { items.first { $0.id == selection.selectedId } }

    public func reportProblem(_ message: String?) {
        problem = message
    }

    // MARK: Refresh

    public func refresh() async {
        listing = source.listing()
        do {
            records = try await store.all()
            try await refreshStoredMetadata()
        } catch {
            problem = "Could not read saved pins: \(error)"
        }
        rebuild()
    }

    /// While the pane is open, items already on screen keep their positions.
    public func paneVisibilityChanged(visible: Bool) {
        isPaneVisible = visible
        speechAnnouncer?.setPaneVisible(visible)
        frozenOrder = visible ? items.map(\.id) : nil
        // A status can have gone stale since the last event, and nothing announces that, so look again.
        if visible { rebuild() }
        if visible {
            focusRequest += 1
            if selection.selectedId == nil { selection.reset(to: items) }
        } else {
            routeChoice = nil
            feedback = nil
        }
    }

    // MARK: Keyboard

    public func moveSelection(down: Bool) {
        if var choice = routeChoice {
            let last = max(choice.item.routes.count - 1, 0)
            choice.index = min(max(choice.index + (down ? 1 : -1), 0), last)
            routeChoice = choice
            return
        }
        if down { selection.moveDown(in: items) } else { selection.moveUp(in: items) }
        feedback = nil
        notice = nil
    }

    public func select(_ item: PanelItem) {
        selection.select(item.id)
        feedback = nil
        notice = nil
    }

    /// Escape: leave the route chooser or feedback first; returns false when the pane should close.
    public func escape() -> Bool {
        if routeChoice != nil { routeChoice = nil; return true }
        if feedback != nil { feedback = nil; return true }
        if !query.isEmpty { query = ""; return true }
        return false
    }

    public func toggleShowHidden() {
        showHidden.toggle()
        rebuild()
    }

    public func toggleOlder() {
        let previous = items
        olderExpanded.toggle()
        selection.reconcile(with: items, previous: previous)
        onContentChanged()
    }


}

extension PanelItem {
    var snapshot: ConversationSnapshot {
        ConversationSnapshot(key: key, title: title, canonicalUrl: canonicalUrl, profileAlias: profileAlias)
    }
}
