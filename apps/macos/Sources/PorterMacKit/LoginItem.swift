import Foundation
import ServiceManagement

public enum LoginItemState: Sendable, Equatable {
    /// Running unbundled (development), so there is no app for macOS to open at login.
    case notAvailable
    case off
    case on
    /// Registered, but macOS wants the user to switch it on under Login Items.
    case needsApproval
}

public protocol LoginItemControlling: Sendable {
    var state: LoginItemState { get }
    func setEnabled(_ enabled: Bool) throws
}

/// Opens Porter when the user logs in, through the system's login-item service.
public struct LiveLoginItem: LoginItemControlling {
    public init() {}

    public var state: LoginItemState {
        guard Bundle.main.bundlePath.hasSuffix(".app") else { return .notAvailable }
        switch SMAppService.mainApp.status {
        case .enabled: return .on
        case .requiresApproval: return .needsApproval
        case .notRegistered: return .off
        case .notFound: return .notAvailable
        @unknown default: return .notAvailable
        }
    }

    public func setEnabled(_ enabled: Bool) throws {
        if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
    }
}
