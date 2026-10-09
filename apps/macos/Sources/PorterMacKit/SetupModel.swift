import AppKit
import Foundation
import NativeSources
import Observation
import PorterPanelModel

/// What the setup window shows and does. It reads the sources' state; it never changes a source by itself.
@MainActor
@Observable
public final class SetupModel {
    public private(set) var sections: [SetupSection] = []
    public private(set) var summary = ""
    /// What the last setup step did, in plain words, shown under the list.
    public private(set) var message: String?
    public private(set) var isWorking = false

    private let readInputs: @MainActor () -> SetupInputs
    private let performer: any RecoveryPerformer
    private let installer: SetupInstaller
    private let editors: @MainActor () -> [SetupEnvironment.Editor]
    /// Asks before a step that changes another app's settings; returns whether to go ahead.
    private let confirm: @MainActor (_ title: String, _ detail: String) -> Bool
    private let reveal: @MainActor (_ folder: String) -> Void

    static let automationSettings = "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
    static let accessibilitySettings = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

    public init(
        performer: any RecoveryPerformer, installer: SetupInstaller = SetupInstaller(),
        editors: @escaping @MainActor () -> [SetupEnvironment.Editor] = { SetupEnvironment.installedEditors() },
        confirm: @escaping @MainActor (String, String) -> Bool = { _, _ in false },
        reveal: @escaping @MainActor (String) -> Void = { _ in },
        readInputs: @escaping @MainActor () -> SetupInputs
    ) {
        self.performer = performer
        self.installer = installer
        self.editors = editors
        self.confirm = confirm
        self.reveal = reveal
        self.readInputs = readInputs
        refresh()
    }

    public func refresh() {
        let found = SetupChecklist.sections(for: readInputs())
        if found != sections { sections = found }
        let text = SetupChecklist.summary(found)
        if text != summary { summary = text }
    }

    public func perform(_ action: SetupAction) {
        switch action {
        case .openAutomationSettings:
            open(Self.automationSettings)
        case .requestAccessibility:
            // The prompt appears only for a process that is not yet trusted; the pane is opened as well, because
            // the prompt is easy to dismiss.
            _ = LiveAccessibility.requestTrust()
            open(Self.accessibilitySettings)
        case .openApplication(let host):
            performer.launch(host)
        case .installEditorCompanion:
            run { [self] in await installer.installEditorCompanions(editors()) }
        case .enableClaudeCodeStatus:
            guard confirm("Turn on Claude Code status?", "Porter will add its hooks to Claude Code's settings (~/.claude/settings.json). A backup is made first and your other settings are kept.") else { return }
            run { [self] in await installer.enableClaudeCodeStatus() }
        case .setUpChromeExtension:
            let prepared = installer.prepareChromeExtension()
            message = prepared.message
            if let folder = prepared.folder { reveal(folder) }
        }
    }

    /// One step at a time: a second press while one runs is ignored, so nothing is installed twice at once.
    private func run(_ step: @escaping @MainActor () async -> String) {
        guard !isWorking else { return }
        isWorking = true
        message = "Working…"
        Task { [self] in
            let outcome = await step()
            message = outcome
            isWorking = false
            refresh()
        }
    }

    private func open(_ address: String) {
        guard let url = URL(string: address) else { return }
        NSWorkspace.shared.open(url)
    }
}
