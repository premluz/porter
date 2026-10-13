import AppKit
import CoreGraphics
import Foundation

/// Missing initial evidence keeps speech quiet; an interaction in Setup also proves the session is unlocked.
@MainActor
final class ScreenLockMonitor {
    private static let locked = Notification.Name("com.apple.screenIsLocked")
    private static let unlocked = Notification.Name("com.apple.screenIsUnlocked")
    private static let lockKey = "CGSSessionScreenIsLocked"
    private var observers: [any NSObjectProtocol] = []
    private let onChange: (Bool) -> Void

    init(onChange: @escaping (Bool) -> Void) {
        self.onChange = onChange
        let dictionary = CGSessionCopyCurrentDictionary() as NSDictionary?
        let known = dictionary?.object(forKey: Self.lockKey) as? NSNumber
        onChange(known?.boolValue ?? true)
        let center = DistributedNotificationCenter.default()
        observers.append(center.addObserver(forName: Self.locked, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.onChange(true) }
        })
        observers.append(center.addObserver(forName: Self.unlocked, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.onChange(false) }
        })
    }

    isolated deinit {
        for observer in observers { DistributedNotificationCenter.default().removeObserver(observer) }
    }
}
