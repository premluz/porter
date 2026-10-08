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
    static let table = Mutex<[UInt32: @Sendable () -> Void]>([:])
    static let handlerInstalled = Mutex(false)

    static func fire(_ id: UInt32) {
        table.withLock { $0[id] }?()
    }
}

/// A system-wide shortcut through the Carbon hot key API, which needs no Accessibility permission.
public final class GlobalHotKey {
    public static let controlOptionSpace = (keyCode: UInt32(kVK_Space), modifiers: UInt32(controlKey | optionKey))
    private static let signature: OSType = 0x504F5254
    private static let nextId = Mutex<UInt32>(1)

    private let id: UInt32
    private var reference: EventHotKeyRef?

    public init(keyCode: UInt32, modifiers: UInt32, action: @escaping @Sendable () -> Void) throws(HotKeyError) {
        try Self.installHandlerOnce()
        id = Self.nextId.withLock { value in
            defer { value += 1 }
            return value
        }
        HotKeyActions.table.withLock { $0[id] = action }
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
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            let read = GetEventParameter(
                event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID
            )
            if read == noErr { HotKeyActions.fire(hotKeyID.id) }
            return noErr
        }, 1, &eventType, nil, nil)
        guard status == noErr else {
            HotKeyActions.handlerInstalled.withLock { $0 = false }
            throw .handlerInstallFailed(status: status)
        }
    }
}
