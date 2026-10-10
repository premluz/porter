import Foundation
import Testing
@testable import BridgeTransport

private struct FakeTable: ProcessTable {
    let records: [Int32: ProcessRecord]
    func record(for pid: Int32) -> ProcessRecord? { records[pid] }
}

@Suite("Finding the terminal an agent runs in")
struct TerminalProbeTests {
    private func table(_ records: [ProcessRecord]) -> FakeTable {
        FakeTable(records: Dictionary(uniqueKeysWithValues: records.map { ($0.pid, $0) }))
    }

    private let bundles: @Sendable (String) -> String? = { path in
        ["/System/Applications/Utilities/Terminal.app": "com.apple.Terminal", "/Applications/Visual Studio Code.app": "com.microsoft.VSCode"][path]
    }

    @Test("walking up from the hook finds the agent's terminal device and the application hosting it")
    func terminalApp() {
        let chain = table([
            ProcessRecord(pid: 10, parent: 9, tty: nil, executablePath: "/bin/sh"),
            ProcessRecord(pid: 9, parent: 8, tty: "ttys003", executablePath: "/Users/example/.local/bin/claude"),
            ProcessRecord(pid: 8, parent: 7, tty: "ttys003", executablePath: "/bin/zsh"),
            ProcessRecord(pid: 7, parent: 6, tty: "ttys003", executablePath: "/usr/bin/login"),
            ProcessRecord(pid: 6, parent: 1, tty: nil, executablePath: "/System/Applications/Utilities/Terminal.app/Contents/MacOS/Terminal"),
        ])
        #expect(TerminalProbe.probe(from: 10, table: chain, bundleId: bundles) == TerminalProbe.Placement(tty: "ttys003", hostApp: "com.apple.Terminal"))
    }

    @Test("a helper process inside an application is attributed to the outermost application, not the helper's own bundle")
    func outermostApplication() {
        let chain = table([
            ProcessRecord(pid: 5, parent: 4, tty: "ttys009", executablePath: "/bin/zsh"),
            ProcessRecord(pid: 4, parent: 1, tty: nil, executablePath: "/Applications/Visual Studio Code.app/Contents/Frameworks/Code Helper (Plugin).app/Contents/MacOS/Code Helper (Plugin)"),
        ])
        #expect(TerminalProbe.probe(from: 5, table: chain, bundleId: bundles).hostApp == "com.microsoft.VSCode")
    }

    @Test("an unknown chain, a loop and a missing process end the walk with what was found, never a guess")
    func edges() {
        #expect(TerminalProbe.probe(from: 99, table: table([]), bundleId: bundles) == TerminalProbe.Placement(tty: nil, hostApp: nil))
        let loop = table([ProcessRecord(pid: 5, parent: 6, tty: "ttys001", executablePath: nil), ProcessRecord(pid: 6, parent: 5, tty: nil, executablePath: nil)])
        #expect(TerminalProbe.probe(from: 5, table: loop, bundleId: bundles) == TerminalProbe.Placement(tty: "ttys001", hostApp: nil))
        let unknownApp = table([ProcessRecord(pid: 5, parent: 1, tty: "ttys001", executablePath: "/Applications/Other.app/Contents/MacOS/Other")])
        #expect(TerminalProbe.probe(from: 5, table: unknownApp, bundleId: bundles).hostApp == nil)
    }

    @Test("the real process table knows this process: its parent, and the path of its own executable")
    func liveTable() {
        let me = LiveProcessTable().record(for: getpid())
        #expect(me?.parent == getppid() && me?.executablePath?.isEmpty == false)
    }
}
