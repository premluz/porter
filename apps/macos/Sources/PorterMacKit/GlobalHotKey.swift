import Carbon.HIToolbox
import Foundation
import Synchronization

public enum HotKeyError: Error, Equatable, Sendable {
    case handlerInstallFailed(status: Int32)
    /// Usually means another app already owns this shortcut.
    case registrationFailed(status: Int32)
}

/// The C event handler cannot capture anything, so it looks actions up here by hot key ID.
private enum HotKeyActions {
    struct Actions: Sendable {
        let pressed: @Sendable () -> Void
        let released: (@Sendable () -> Void)?
    }
    static let table = Mutex<[UInt32: Actions]>([:])
    static let handlerInstalled = Mutex(false)

    static func fire(_ id: UInt32, released: Bool) {
        guard let actions = table.withLock({ $0[id] }) else { return }
        if released { actions.released?() } else { actions.pressed() }
    }
}

/// A system-wide shortcut through the Carbon hot key API, which needs no Accessibility permission.
public final class GlobalHotKey {
    public static let controlOptionSpace = (keyCode: UInt32(kVK_Space), modifiers: UInt32(controlKey | optionKey))
    public static let controlOptionV = (keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(controlKey | optionKey))
    private static let signature: OSType = 0x504F5254
    private static let nextId = Mutex<UInt32>(1)

    private let id: UInt32
    private var reference: EventHotKeyRef?

    public init(
        keyCode: UInt32, modifiers: UInt32, action: @escaping @Sendable () -> Void,
        onRelease: (@Sendable () -> Void)? = nil
    ) throws(HotKeyError) {
        try Self.installHandlerOnce()
        id = Self.nextId.withLock { value in
            defer { value += 1 }
            return value
        }
        HotKeyActions.table.withLock { $0[id] = .init(pressed: action, released: onRelease) }
        let status = RegisterEventHotKey(
            keyCode, modifiers, EventHotKeyID(signature: Self.signature, id: id), GetApplicationEventTarget(), 0, &reference
        )
        guard status == noErr else {
            HotKeyActions.table.withLock { $0[id] = nil }
            throw .registrationFailed(status: status)
        }
    }

    deinit {
        if let reference { UnregisterEventHotKey(reference) }
        HotKeyActions.table.withLock { $0[id] = nil }
    }

    private static func installHandlerOnce() throws(HotKeyError) {
        let alreadyInstalled = HotKeyActions.handlerInstalled.withLock { installed in
            defer { installed = true }
            return installed
        }
        guard !alreadyInstalled else { return }
        let eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            let read = GetEventParameter(
                event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID
            )
            if read == noErr { HotKeyActions.fire(hotKeyID.id, released: GetEventKind(event) == UInt32(kEventHotKeyReleased)) }
            return noErr
        }, eventTypes.count, eventTypes, nil, nil)
        guard status == noErr else {
            HotKeyActions.handlerInstalled.withLock { $0 = false }
            throw .handlerInstallFailed(status: status)
        }
    }
}
