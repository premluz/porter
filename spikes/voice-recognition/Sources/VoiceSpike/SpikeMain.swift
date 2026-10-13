import AppKit
import Foundation

@main
enum SpikeMain {
    @MainActor
    static func main() async {
        do { try await run(Array(CommandLine.arguments.dropFirst())) }
        catch {
            fputs("VoiceSpike: \(error)\n", stderr)
            exit(EXIT_FAILURE)
        }
    }

    @MainActor
    private static func run(_ args: [String]) async throws {
        guard let command = args.first else { throw usage() }
        if command == "permissions", args.count == 1 {
            PermissionProbe.show()
            NSApplication.shared.run()
            return
        }
        if command == "capabilities", args.count <= 2 {
            await Capabilities.report(locale: Locale(identifier: args.count == 2 ? args[1] : SpikeConfiguration.defaultLocale))
            return
        }
        guard command == "compare", (3...4).contains(args.count),
              ["analyzer", "legacy"].contains(args[1]) else { throw usage() }
        let locale = Locale(identifier: args.count == 4 ? args[3] : SpikeConfiguration.defaultLocale)
        let manifest = URL(fileURLWithPath: args[2])
        let entries = try Corpus.load(manifest)
        for entry in entries {
            try await trial(entry, manifest: manifest, engine: args[1], locale: locale)
        }
    }

    @MainActor
    private static func trial(_ entry: CorpusEntry, manifest: URL, engine: String, locale: Locale) async throws {
        let start = Date()
        let cpu = try Metrics.cpuSeconds()
        let audio = Corpus.audioURL(entry, relativeTo: manifest)
        let text: String
        if engine == "analyzer" { text = try await AnalyzerRecognition.recognize(audio: audio, locale: locale) }
        else { text = try await LegacyRecognition().recognize(audio: audio, locale: locale) }
        try Metrics.printJSON(TrialMetrics(
            id: entry.id, engine: engine,
            matched: Corpus.normalized(text) == Corpus.normalized(entry.expected),
            wallSeconds: Date().timeIntervalSince(start),
            clientCPUSeconds: try Metrics.cpuSeconds() - cpu
        ))
    }

    private static func usage() -> SpikeError {
        .invalid("Usage: VoiceSpike capabilities [locale] | permissions | compare analyzer|legacy corpus.json [locale]")
    }
}
