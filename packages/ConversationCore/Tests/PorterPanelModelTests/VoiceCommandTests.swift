import Testing
@testable import PorterPanelModel

@Suite("Deterministic voice command grammar")
struct VoiceCommandTests {
    @Test("closed command aliases and boundary fillers")
    func aliases() {
        let cases: [(String, VoiceCommand)] = [
            ("show the task", .showLastTask), ("Porter, open last task", .showLastTask),
            ("show last task", .showLastTask), ("Porter: open last task task", .showLastTask),
            ("show it", .showLastTask),
            ("open it", .showLastTask), ("go there", .showLastTask),
            ("what's waiting", .showNeedsYou), ("what is waiting", .showNeedsYou),
            ("show needs you", .showNeedsYou), ("what’s working?", .describeWorking),
            ("what is working", .describeWorking), ("cancel", .cancel),
            ("stop", .cancel), ("never mind", .cancel),
            ("Uh, Porter, please show it!", .showLastTask),
            ("Porter cancel please", .cancel), ("um please open Fix login please.", .show(query: "Fix login")),
            ("Porter, show Atlas", .show(query: "Atlas")),
            ("reply to Fix login", .dictate(target: "Fix login"))
        ]
        for (transcript, expected) in cases { #expect(CommandParser.parse(transcript) == expected) }
    }

    @Test("names keep meaningful words and symbols instead of interpreting them as commands")
    func names() {
        let cases: [(String, VoiceCommand)] = [
            ("show Stop bug", .show(query: "Stop bug")),
            ("open Please help", .show(query: "Please help")),
            ("show C++ parser", .show(query: "C++ parser")),
            ("show .NET upgrade", .show(query: ".NET upgrade")),
            ("show Porter migration", .show(query: "Porter migration")),
            ("show Fix uh handling", .show(query: "Fix uh handling")),
            ("reply to Atlas ship the build", .dictate(target: "Atlas ship the build"))
        ]
        for (transcript, expected) in cases { #expect(CommandParser.parse(transcript) == expected) }
    }

    @Test("unsupported commands and incomplete targets fail closed")
    func unsupported() {
        for transcript in ["", "  ", "uh please", "Porter", "show", "open please", "reply to",
                           "send Fix login", "approve it", "delete the task", "cancel the deployment", "go nowhere"] {
            #expect(CommandParser.parse(transcript) == nil)
        }
    }
}
