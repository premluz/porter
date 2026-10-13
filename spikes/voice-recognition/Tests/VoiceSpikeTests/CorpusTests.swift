import Foundation
import Testing
@testable import VoiceSpike

@Test func conventionalNamesKeepWordsAndRejectNearMisses() throws {
    let entries = [
        CorpusEntry(id: "project", expected: "Porter", audio: "p.wav"),
        CorpusEntry(id: "chat", expected: "Fix login", audio: "c.wav"),
    ]
    try Corpus.validate(entries, minimum: entries.count)
    #expect(Corpus.normalized(" FIX login! ") == Corpus.normalized(entries[1].expected))
    #expect(Corpus.normalized("fix logging") != Corpus.normalized(entries[1].expected))
}

@Test func differentNamesKeepAccentsAndDigits() throws {
    let entries = [
        CorpusEntry(id: "a", expected: "Étude 12", audio: "a.caf"),
        CorpusEntry(id: "b", expected: "Memento—API", audio: "b.aiff"),
        CorpusEntry(id: "c", expected: "東京", audio: "c.wav"),
    ]
    try Corpus.validate(entries, minimum: entries.count)
    #expect(Corpus.normalized("ÉTUDE 12.") == Corpus.normalized(entries[0].expected))
    #expect(Corpus.normalized("etude 12") != Corpus.normalized(entries[0].expected))
    #expect(Corpus.normalized("Memento API") == Corpus.normalized(entries[1].expected))
    #expect(Corpus.normalized(entries[2].expected) == "東京")
}

@Test func invalidCorporaFailLoudly() {
    let entry = CorpusEntry(id: "a", expected: "Fix login", audio: "a.wav")
    #expect(throws: SpikeError.self) { try Corpus.validate([entry], minimum: 30) }
    #expect(throws: SpikeError.self) { try Corpus.validate([entry, entry], minimum: 2) }
    let duplicate = CorpusEntry(id: "b", expected: "FIX LOGIN!", audio: "b.wav")
    #expect(throws: SpikeError.self) { try Corpus.validate([entry, duplicate], minimum: 2) }
    let empty = CorpusEntry(id: "c", expected: "…", audio: "c.wav")
    #expect(throws: SpikeError.self) { try Corpus.validate([empty], minimum: 1) }
}

@Test func metricsDoNotContainNamesOrTranscripts() throws {
    let metric = TrialMetrics(id: "01", engine: "analyzer", matched: false, wallSeconds: 1, clientCPUSeconds: 0)
    let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(metric))
    let dictionary = try #require(object as? [String: NSObject])
    #expect(Set(dictionary.keys) == ["id", "engine", "matched", "wallSeconds", "clientCPUSeconds"])
}
