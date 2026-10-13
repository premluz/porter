import Speech
import Testing
@testable import PorterMacKit

@MainActor
@Suite("Voice permission callbacks")
struct VoicePermissionTests {
    @Test("speech authorization response can arrive off the main actor")
    func speechResponse() async {
        let model = SetupModel(performer: RecordingPerformer()) { SetupInputs() }
        let callback = model.speechAuthorizationHandler()
        await Task.detached { callback(.authorized) }.value
        for _ in 0..<20 where model.message == nil { await Task.yield() }
        #expect(model.message == "Speech Recognition access is on.")
    }
}
