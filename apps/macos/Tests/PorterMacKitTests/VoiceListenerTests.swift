import Testing
@testable import PorterMacKit

@Suite("Voice listener")
struct VoiceListenerTests {
    @Test("partial transcription survives a later empty result")
    func partialResult() {
        var buffer = VoiceTranscriptBuffer()
        buffer.accept("Porter, show the task")
        buffer.accept("   ")
        buffer.accept(nil)
        #expect(buffer.latest == "Porter, show the task")
    }
}
