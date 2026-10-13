import Foundation
import PorterPanelModel
import UserNotifications

/// Tells the person, on this Mac, that a chat has started waiting on them. Nothing is sent anywhere.
@MainActor
public protocol NeedsYouNotifying: AnyObject {
    func notify(_ item: PanelItem)
    /// The chat no longer waits (answered, or finished), so its notice is taken down.
    func withdraw(ids: Set<String>)
}

public enum NotificationState: Sendable, Equatable {
    /// Running unbundled (development): notifications need a real app.
    case notAvailable
    case notAsked
    case allowed
    case denied
}

/// The system's notifications for a bundled app. It asks for permission only when the person presses the button in the
/// setup window, and posts nothing without it.
@MainActor
public final class UserNotificationNotifier: NSObject, NeedsYouNotifying, Announcing, UNUserNotificationCenterDelegate {
    private let onOpen: () -> Void
    private let onOpenCompletions: ([String]) -> Void
    private nonisolated static let completionIdsKey = "completionIds"
    private static let completionPrefix = "porter.completed."
    public private(set) var state: NotificationState = .notAvailable

    private var center: UNUserNotificationCenter? {
        Bundle.main.bundlePath.hasSuffix(".app") ? UNUserNotificationCenter.current() : nil
    }

    /// `onOpen` runs when the person clicks a notice, so Porter's pane opens on what is waiting.
    public init(onOpenCompletions: @escaping ([String]) -> Void = { _ in }, onOpen: @escaping () -> Void) {
        self.onOpen = onOpen
        self.onOpenCompletions = onOpenCompletions
        super.init()
        center?.delegate = self
    }

    public func refresh() async {
        guard let center else { state = .notAvailable; return }
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: state = .allowed
        case .denied: state = .denied
        case .notDetermined: state = .notAsked
        @unknown default: state = .notAsked
        }
    }

    public func requestAuthorization() async {
        guard let center else { return }
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            NSLog("Porter could not ask for notification permission: \(error)")
        }
        await refresh()
    }

    public func notify(_ item: PanelItem) {
        guard state == .allowed, let center else { return }
        let content = UNMutableNotificationContent()
        content.title = "\(item.projectName ?? ProviderNames.display(item.provider)) needs you"
        content.body = item.title
        content.sound = .default
        content.threadIdentifier = item.id
        center.add(UNNotificationRequest(identifier: item.id, content: content, trigger: nil)) { error in
            if let error { NSLog("Porter could not post a notification: \(error)") }
        }
    }

    public func withdraw(ids: Set<String>) {
        guard !ids.isEmpty, let center else { return }
        center.removeDeliveredNotifications(withIdentifiers: Array(ids))
    }

    public func announce(_ batch: CompletionBatch) {
        guard batch.kind == .completed, !batch.completions.isEmpty, state == .allowed, let center else { return }
        let content = UNMutableNotificationContent()
        if batch.completions.count == 1, let event = batch.completions.first {
            content.title = SpeechTemplates.text(for: batch) ?? "Task completed"
            content.body = [event.projectName, event.title].compactMap { $0 }.joined(separator: " · ")
        } else {
            content.title = SpeechTemplates.text(for: batch) ?? "Tasks completed"
        }
        content.sound = .default
        content.userInfo = [Self.completionIdsKey: batch.completions.map(\.id)]
        let identifier = Self.completionPrefix + UUID().uuidString
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil)) { error in
            if let error { NSLog("Porter could not post a completion notice: \(error)") }
        }
    }

    // A notice for a chat that needs you is shown even while Porter is the front app.
    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions { [.banner, .sound] }

    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
    ) async {
        let ids = response.notification.request.content.userInfo[Self.completionIdsKey] as? [String]
        await MainActor.run {
            if let ids { onOpenCompletions(ids) } else { onOpen() }
        }
    }
}
