import Foundation
import Synchronization

extension AppDelegate {
    func configureVoiceCommands(
        appModel: AppModel, controller: PanelController, speech: SpeechAnnouncer,
        settings: VoiceSettings, setupModel: SetupModel
    ) {
        let listener = VoiceListener()
        let router = VoiceRouter(model: appModel, controller: controller, speech: speech)
        listener.onTranscript = { transcript in Task { await router.handle(transcript) } }
        listener.onError = { [weak appModel, weak controller] message in
            appModel?.reportProblem(message)
            controller?.open()
        }
        listener.onListeningChanged = { [weak appModel, weak speech] listening in
            appModel?.isListening = listening
            speech?.setListening(listening)
        }
        voiceListener = listener
        setupModel.voicePolicyChanged = { [weak listener] in
            speech.refreshPolicy()
            if !settings.voiceCommands { listener?.cancel() }
        }
    }

    func registerVoiceHotKey(settings: VoiceSettings, notes: inout [String]) {
        let keys = GlobalHotKey.controlOptionV
        let held = Mutex(false)
        do {
            voiceHotKey = try GlobalHotKey(keyCode: keys.keyCode, modifiers: keys.modifiers, action: { [weak self] in
                held.withLock { $0 = true }
                Task { @MainActor in
                    if held.withLock({ $0 }), settings.voiceCommands { self?.voiceListener?.start() }
                }
            }, onRelease: { [weak self] in
                held.withLock { $0 = false }
                Task { @MainActor in self?.voiceListener?.stop() }
            })
        } catch {
            notes.append("Voice shortcut ⌃⌥V is unavailable (\(error)).")
        }
    }
}
