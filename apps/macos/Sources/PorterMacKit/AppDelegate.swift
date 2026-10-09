import AppKit
import BridgeTransport
import Foundation
import PorterPanelModel
import PorterStore

public enum LaunchMode: Sendable {
    case live
    case fixtures
}

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private let mode: LaunchMode
    private var controller: PanelController?
    private var statusItem: StatusItemController?
    private var setupWindow: SetupWindowController?
    private var hotKey: GlobalHotKey?

    public init(mode: LaunchMode) {
        self.mode = mode
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        var notes: [String] = []
        let setup = makeSetup(notes: &notes)
        let controller = PanelController(model: setup.model, settings: PanelSettings.load(from: .standard))
        self.controller = controller
        controller.show()
        registerHotKey(for: controller, notes: &notes)
        let setupModel = SetupModel(
            performer: WorkspaceRecoveryPerformer(), confirm: Self.confirm, reveal: Self.reveal
        ) { [source = setup.source] in source.setupInputs() }
        let setupWindow = SetupWindowController(model: setupModel)
        self.setupWindow = setupWindow
        statusItem = StatusItemController(controller: controller, setup: setupWindow, notes: notes)
        if mode == .live { setupWindow.showOnFirstLaunch() }
        setup.source.setChangeHandler { [model = setup.model] in Task { @MainActor in await model.refresh() } }
        Task {
            await setup.prepare()
            await setup.model.refresh()
        }
    }

    private struct Setup {
        let model: AppModel
        let source: any DestinationSource
        /// Work that must finish before the first refresh, such as seeding sample pins.
        var prepare: @MainActor () async -> Void = {}
    }

    private func makeSetup(notes: inout [String]) -> Setup {
        let performer = WorkspaceRecoveryPerformer()
        switch mode {
        case .fixtures:
            notes.append("Showing sample data")
            let store = Self.require { try PreferenceStore(path: PreferenceStore.inMemoryPath, deviceId: UUID()) }
            let source = FixtureSource()
            let model = AppModel(source: source, store: store, performer: performer)
            return Setup(model: model, source: source) {
                do {
                    try await SampleData.seedPins(into: store, at: Date())
                } catch {
                    model.reportProblem("Could not add sample pins: \(error)")
                }
            }
        case .live:
            return liveSetup(performer: performer, notes: &notes)
        }
    }

    private func liveSetup(performer: WorkspaceRecoveryPerformer, notes: inout [String]) -> Setup {
        let store = Self.require { try Self.openStore() }
        let source = LiveRegistrySource { FileHandle.standardError.write(Data("\($0)\n".utf8)) }
        let model = AppModel(source: source, store: store, performer: performer)
        do {
            try source.start()
        } catch {
            let message = Self.describe(error)
            model.reportProblem(message)
            notes.append(message)
        }
        source.attachNativeSources()
        return Setup(model: model, source: source)
    }

    private static func confirm(_ title: String, _ detail: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = detail
        alert.addButton(withTitle: "Turn on")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate()
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// Shows the extension's folder in Finder and opens Chrome's extensions page, where it is loaded by hand.
    private static func reveal(_ folder: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: folder)])
        guard let chrome = NSWorkspace.shared.urlForApplication(withBundleIdentifier: HostApplication.chrome.bundleIdentifier),
              let page = URL(string: "chrome://extensions") else { return }
        NSWorkspace.shared.open([page], withApplicationAt: chrome, configuration: NSWorkspace.OpenConfiguration())
    }

    private func registerHotKey(for controller: PanelController, notes: inout [String]) {
        let keys = GlobalHotKey.controlOptionSpace
        do {
            hotKey = try GlobalHotKey(keyCode: keys.keyCode, modifiers: keys.modifiers) {
                Task { @MainActor in controller.toggle() }
            }
        } catch {
            notes.append("Shortcut ⌃⌥Space is unavailable (\(error)). Use the menu bar item.")
        }
    }

    private static func openStore() throws(StoreError) -> PreferenceStore {
        let directory = PorterPaths.supportDirectory()
        do {
            try FileManager.default.createDirectory(
                atPath: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]
            )
        } catch {
            throw .fileProtection(path: directory, reason: String(describing: error))
        }
        return try PreferenceStore(path: directory + "/porter.sqlite", deviceId: Self.deviceId())
    }

    /// A stable per-install ID so revisions can say which device made a change.
    private static func deviceId() -> UUID {
        let key = "porter.deviceId"
        if let text = UserDefaults.standard.string(forKey: key), let id = UUID(uuidString: text) { return id }
        let id = UUID()
        UserDefaults.standard.set(id.uuidString, forKey: key)
        return id
    }

    private static func describe(_ error: SocketError) -> String {
        switch error {
        case .alreadyRunning: "Another Porter registry (porter-registryd) is already running. Quit it, then relaunch."
        default: "Could not start the Porter registry: \(error)"
        }
    }

    /// Startup cannot continue without a store; say why and exit rather than run half-broken.
    private static func require<T>(_ make: () throws -> T) -> T {
        do {
            return try make()
        } catch {
            FileHandle.standardError.write(Data("Porter cannot start: \(error)\n".utf8))
            exit(1)
        }
    }
}
