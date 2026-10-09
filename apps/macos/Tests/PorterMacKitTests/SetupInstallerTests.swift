import ConversationCore
import Foundation
import NativeSources
import PorterPanelModel
import Synchronization
import Testing
@testable import PorterMacKit

final class FakeCommands: CommandRunning {
    struct Call: Equatable { let executable: String; let arguments: [String]; let environment: [String: String] }
    private let state = Mutex<(calls: [Call], statuses: [Int32])>(([], []))

    init(statuses: [Int32] = []) { state.withLock { $0.statuses = statuses } }
    var calls: [Call] { state.withLock { $0.calls } }

    func run(_ executable: String, arguments: [String], environment: [String: String]) async -> CommandResult {
        state.withLock { state in
            state.calls.append(Call(executable: executable, arguments: arguments, environment: environment))
            let status = state.statuses.isEmpty ? 0 : state.statuses.removeFirst()
            return CommandResult(status: status, output: status == 0 ? "ok" : "it failed")
        }
    }
}

private func editor(_ name: String) -> SetupEnvironment.Editor {
    SetupEnvironment.Editor(name: name, bundleId: "x.\(name)", cliName: "cli", applicationPath: "/Applications/\(name).app")
}

@Suite("The setup steps that change something outside Porter")
struct SetupInstallerTests {
    private let assets = BundledAssets(
        vsix: "/App/porter-vscode.vsix", hookScript: "/App/claude-hooks.sh", porterctl: "/App/Helpers/porterctl",
        nativeHost: "/bin/echo", chromeExtensionFolder: URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().appending(path: "extensions/chrome").path
    )

    @Test("the companion is installed in each editor with its own command, and one failure does not hide the others")
    func installsCompanions() async {
        let runner = FakeCommands(statuses: [0, 1])
        let message = await SetupInstaller(assets: assets, runner: runner)
            .installEditorCompanions([editor("VS Code"), editor("Cursor")])
        #expect(runner.calls.map(\.executable) == ["/Applications/VS Code.app/Contents/Resources/app/bin/cli", "/Applications/Cursor.app/Contents/Resources/app/bin/cli"])
        #expect(runner.calls.allSatisfy { $0.arguments == ["--install-extension", "/App/porter-vscode.vsix", "--force"] })
        #expect(message.contains("Installed in VS Code") && message.contains("Could not install in Cursor"))
    }

    @Test("nothing runs when the companion is not bundled or no editor is installed")
    func companionPreconditions() async {
        let runner = FakeCommands()
        #expect(await SetupInstaller(assets: BundledAssets(), runner: runner).installEditorCompanions([editor("VS Code")]).contains("not bundled"))
        #expect(await SetupInstaller(assets: assets, runner: runner).installEditorCompanions([]).contains("No VS Code-family editor"))
        #expect(runner.calls.isEmpty)
    }

    @Test("the hook script is run with the bundled control tool and --apply, and a failure says nothing was changed")
    func hooks() async {
        let ok = FakeCommands()
        #expect(await SetupInstaller(assets: assets, runner: ok).enableClaudeCodeStatus().contains("backup was made"))
        #expect(ok.calls == [FakeCommands.Call(executable: "/bin/bash", arguments: ["/App/claude-hooks.sh", "--apply"], environment: ["PORTERCTL": "/App/Helpers/porterctl"])])
        let failing = FakeCommands(statuses: [2])
        #expect(await SetupInstaller(assets: assets, runner: failing).enableClaudeCodeStatus().contains("nothing was changed"))
        #expect(await SetupInstaller(assets: BundledAssets(), runner: ok).enableClaudeCodeStatus().contains("not bundled"))
    }

    @Test("preparing the Chrome extension registers the relay and returns the folder to load")
    func chromeExtension() throws {
        let directory = NSTemporaryDirectory() + "porter-setup-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let prepared = SetupInstaller(assets: assets, runner: FakeCommands(), chromeDirectory: directory + "/Chrome", supportDirectory: directory + "/Support")
            .prepareChromeExtension()
        #expect(prepared.folder == assets.chromeExtensionFolder && prepared.message.contains("Load unpacked"))
        #expect(FileManager.default.fileExists(atPath: directory + "/Chrome/NativeMessagingHosts/com.porter.bridge.json"))
        let unbundled = SetupInstaller(assets: BundledAssets(), runner: FakeCommands()).prepareChromeExtension()
        #expect(unbundled.folder == nil && unbundled.message.contains("not bundled"))
    }
}

@MainActor
@Suite("The setup window runs those steps one at a time and asks first when settings change")
struct SetupActionTests {
    private func inputs() -> SetupInputs {
        SetupInputs(chrome: .ready, installedEditors: ["VS Code"], claudeCodeHook: false, canInstallCompanion: true, canEnableClaudeCodeStatus: true, canSetUpChromeExtension: true)
    }

    private func settle(_ model: SetupModel) async {
        for _ in 0..<200 where model.isWorking { try? await Task.sleep(for: .milliseconds(10)) }
    }

    @Test("the buttons are offered only when the build carries what they need")
    func offered() {
        func actions(_ inputs: SetupInputs) -> Set<String> {
            Set(SetupChecklist.sections(for: inputs).flatMap(\.rows).compactMap { $0.action.map { "\($0)" } })
        }
        #expect(actions(inputs()) == ["installEditorCompanion", "enableClaudeCodeStatus", "setUpChromeExtension"])
        var bare = inputs()
        bare.canInstallCompanion = false
        bare.canEnableClaudeCodeStatus = false
        bare.canSetUpChromeExtension = false
        #expect(actions(bare).isEmpty)
    }

    @Test("turning on Claude Code status does nothing unless the user confirms")
    func confirmation() async {
        let runner = FakeCommands()
        let assets = BundledAssets(hookScript: "/App/claude-hooks.sh", porterctl: "/App/Helpers/porterctl")
        var answer = false
        let model = SetupModel(performer: RecordingPerformer(), installer: SetupInstaller(assets: assets, runner: runner), confirm: { _, _ in answer }) { inputs() }
        model.perform(.enableClaudeCodeStatus)
        #expect(runner.calls.isEmpty && model.message == nil)
        answer = true
        model.perform(.enableClaudeCodeStatus)
        await settle(model)
        #expect(runner.calls.count == 1 && model.message?.contains("backup was made") == true)
    }

    @Test("a second press while a step runs is ignored")
    func oneAtATime() async {
        let runner = FakeCommands()
        let assets = BundledAssets(vsix: "/App/porter-vscode.vsix")
        let model = SetupModel(
            performer: RecordingPerformer(), installer: SetupInstaller(assets: assets, runner: runner),
            editors: { [editor("VS Code")] }
        ) { inputs() }
        model.perform(.installEditorCompanion)
        model.perform(.installEditorCompanion)
        await settle(model)
        #expect(runner.calls.count == 1)
    }
}
