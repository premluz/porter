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

    private let readInputs: @MainActor () -> SetupInputs
    private let performer: any RecoveryPerformer

    static let automationSettings = "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
    static let accessibilitySettings = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

    public init(performer: any RecoveryPerformer, readInputs: @escaping @MainActor () -> SetupInputs) {
        self.performer = performer
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
        }
    }

    private func open(_ address: String) {
        guard let url = URL(string: address) else { return }
        NSWorkspace.shared.open(url)
    }
}
