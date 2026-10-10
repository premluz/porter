import ConversationCore
import Foundation
import NativeSources
import PorterPanelModel
import Testing
@testable import PorterMacKit

@Suite("The setup checklist says what works, what needs permission and what is simply not open")
struct SetupChecklistTests {
    private func rows(_ inputs: SetupInputs) -> [String: SetupRow] {
        Dictionary(uniqueKeysWithValues: SetupChecklist.sections(for: inputs).flatMap(\.rows).map { ($0.id, $0) })
    }

    private func connector(_ type: ConnectorType, up: Bool = true) -> ConnectorSummary {
        ConnectorSummary(
            connectorId: "\(type)-\(UUID())", profileAlias: nil, reachability: up ? .connected : .disconnected, routeCount: 0,
            providerType: type, adapterVersions: ["claude-code": "0.2.0"]
        )
    }

    @Test("a refused Automation permission offers the settings pane, an unopened browser offers to open it")
    func chrome() {
        let denied = rows(SetupInputs(chrome: .permissionDenied))["chrome"]
        #expect(denied?.state == .needsAction && denied?.action == .openAutomationSettings)
        let closed = rows(SetupInputs(chrome: .notRunning))["chrome"]
        #expect(closed?.state == .waiting && closed?.action == .openApplication(.chrome))
        #expect(rows(SetupInputs(chrome: .ready))["chrome"]?.state == .ready)
        #expect(rows(SetupInputs(chrome: .failed("timed out")))["chrome"]?.detail.contains("timed out") == true)
    }

    @Test("a desktop app without Accessibility asks for it; an unreadable layout shows its reason and no button")
    func apps() {
        let inputs = SetupInputs(claudeApp: .permissionDenied, chatgptApp: .failed("no Recents list is visible; open the sidebar"))
        let found = rows(inputs)
        #expect(found["claudeApp"]?.action == .requestAccessibility && found["claudeApp"]?.state == .needsAction)
        #expect(found["chatgptApp"]?.detail.hasPrefix("No Recents list") == true && found["chatgptApp"]?.action == nil)
    }

    @Test("sources that are not attached are not listed, so sample-data mode shows no false problems")
    func sampleData() {
        #expect(SetupChecklist.sections(for: SetupInputs()).isEmpty)
        #expect(SetupChecklist.summary(SetupChecklist.sections(for: SetupInputs())) == "Showing sample data")
    }

    @Test("extension and companion rows count only connected connectors of their own kind")
    func extras() {
        let inputs = SetupInputs(
            chrome: .ready,
            connectors: [connector(.chromeExtension), connector(.chromeExtension, up: false), connector(.chromeScripting), connector(.vscodeExtension)],
            installedEditors: ["VS Code"]
        )
        let found = rows(inputs)
        #expect(found["chromeExtension"]?.detail == "1 profile connected." && found["chromeExtension"]?.state == .ready)
        #expect(found["editors"]?.detail == "1 window connected.")
        let none = rows(SetupInputs(chrome: .ready, installedEditors: ["VS Code", "Cursor"]))
        #expect(none["chromeExtension"]?.state == .optional)
        #expect(none["editors"]?.state == .optional && none["editors"]?.detail.contains("VS Code, Cursor") == true)
        #expect(rows(SetupInputs(chrome: .ready))["editors"] == nil)
    }

    @Test("the Claude Code hook row appears only when it could be read")
    func hook() {
        #expect(rows(SetupInputs(chrome: .ready, claudeCodeHook: nil))["claudeCodeStatus"] == nil)
        #expect(rows(SetupInputs(chrome: .ready, claudeCodeHook: false))["claudeCodeStatus"]?.state == .optional)
        #expect(rows(SetupInputs(chrome: .ready, claudeCodeHook: true))["claudeCodeStatus"]?.state == .ready)
    }

    @Test("the summary counts what is ready and what needs permission, and treats unopened apps as fine")
    func summary() {
        func text(_ inputs: SetupInputs) -> String { SetupChecklist.summary(SetupChecklist.sections(for: inputs)) }
        #expect(text(SetupInputs(chrome: .ready, claudeApp: .ready, chatgptApp: .ready)) == "All ready")
        #expect(text(SetupInputs(chrome: .permissionDenied, claudeApp: .ready, chatgptApp: .notRunning)) == "1 of 3 ready; 1 needs your permission")
        #expect(text(SetupInputs(chrome: .ready, claudeApp: .notRunning, chatgptApp: .notRunning)) == "1 of 3 ready; the rest are not open")
    }
}

@MainActor
@Suite("The setup window's model and the facts it reads")
struct SetupModelTests {
    @Test("it follows the sources as they change, and opening an app goes through the recovery performer")
    func refreshAndAct() {
        let performer = RecordingPerformer()
        var inputs = SetupInputs(chrome: .notRunning)
        let model = SetupModel(performer: performer) { inputs }
        #expect(model.summary == "0 of 1 ready; the rest are not open")
        inputs.chrome = .ready
        model.refresh()
        #expect(model.summary == "All ready")
        model.perform(.openApplication(.chrome))
        #expect(performer.launched == [.chrome])
    }

    @Test("the hook is found by Porter's own marker, a missing file means none, and an unreadable one is not guessed")
    func hookDetection() throws {
        let directory = NSTemporaryDirectory() + "porter-setup-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let withHook = directory + "/with.json"
        let without = directory + "/without.json"
        try #"{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"/x/porterctl hook"}]}]}}"#.write(toFile: withHook, atomically: true, encoding: .utf8)
        try #"{"model":"x"}"#.write(toFile: without, atomically: true, encoding: .utf8)
        #expect(SetupEnvironment.claudeCodeHookInstalled(settingsPath: withHook) == true)
        #expect(SetupEnvironment.claudeCodeHookInstalled(settingsPath: without) == false)
        #expect(SetupEnvironment.claudeCodeHookInstalled(settingsPath: directory + "/missing.json") == false)
        #expect(SetupEnvironment.claudeCodeHookInstalled(settingsPath: directory) == nil)
    }
}

@Suite("Windows running an out-of-date companion are named, not left to look broken")
struct CompanionVersionTests {
    private func window(_ version: String?, up: Bool = true) -> ConnectorSummary {
        ConnectorSummary(
            connectorId: "vscode-\(UUID())", profileAlias: "Folder", reachability: up ? .connected : .disconnected, routeCount: 1,
            providerType: .vscodeExtension, adapterVersions: version.map { ["claude-code": $0, "codex": $0] } ?? [:]
        )
    }

    private func row(_ windows: [ConnectorSummary]) -> SetupRow? {
        SetupChecklist.sections(for: SetupInputs(chrome: .ready, connectors: windows)).flatMap(\.rows).first { $0.id == "editors" }
    }

    @Test("an old or unknown version needs a reload; the current one is ready; a closed window does not count")
    func versions() {
        #expect(row([window("0.2.0"), window("0.3.1")])?.state == .ready)
        let mixed = row([window("0.2.0"), window("0.1.0"), window("0.1.0", up: false)])
        #expect(mixed?.state == .needsAction && mixed?.detail.contains("1 of them need a reload") == true)
        #expect(row([window("0.1.0"), window("0.1.0")])?.detail.contains("All of them need a reload") == true)
        #expect(row([window(nil)])?.state == .needsAction)
        #expect(row([window("0.10.0")])?.state == .ready)
    }
}

@Suite("The Codex threads row")
struct CodexRowTests {
    @Test("it appears only when Codex's thread list was found, and counts as a ready source")
    func row() {
        func ids(_ inputs: SetupInputs) -> [String] { SetupChecklist.sections(for: inputs).flatMap(\.rows).map(\.id) }
        #expect(!ids(SetupInputs(chrome: .ready)).contains("codexThreads"))
        #expect(ids(SetupInputs(chrome: .ready, codexThreads: .ready)).contains("codexThreads"))
        #expect(SetupChecklist.summary(SetupChecklist.sections(for: SetupInputs(chrome: .ready, codexThreads: .ready))) == "All ready")
    }
}

@Suite("Each source says what it reads")
struct ReadsLineTests {
    @Test("every listed source carries a line saying what it reads, and the line promises no more than the privacy doc allows")
    func everyRowHasALine() {
        let inputs = SetupInputs(
            chrome: .ready, claudeApp: .ready, chatgptApp: .ready, codexThreads: .ready, installedEditors: ["VS Code"],
            claudeCodeHook: false
        )
        let rows = SetupChecklist.sections(for: inputs).flatMap(\.rows).filter { $0.id != "launchAtLogin" }
        #expect(!rows.isEmpty && rows.allSatisfy { $0.reads?.hasPrefix("Reads") == true || $0.reads?.hasPrefix("Posts") == true })
        #expect(rows.compactMap(\.reads).allSatisfy { !$0.lowercased().contains("message text") })
    }

    @Test("the statement says nothing leaves the Mac")
    func statement() {
        #expect(SetupChecklist.privacyStatement.hasPrefix("Nothing leaves this Mac"))
    }
}

@Suite("The terminal agents row")
struct TerminalRowTests {
    @Test("it counts the agents that have reported, says how to get one when none has, and is absent when not watched")
    func row() {
        func row(_ count: Int?) -> SetupRow? {
            SetupChecklist.sections(for: SetupInputs(chrome: .ready, terminalAgents: count)).flatMap(\.rows).first { $0.id == "terminalAgents" }
        }
        #expect(row(nil) == nil)
        #expect(row(0)?.state == .optional && row(0)?.detail.contains("Claude Code status") == true)
        #expect(row(2)?.state == .ready && row(2)?.detail.hasPrefix("2 agents") == true)
        #expect(row(1)?.detail.hasPrefix("1 agent ") == true)
    }
}
