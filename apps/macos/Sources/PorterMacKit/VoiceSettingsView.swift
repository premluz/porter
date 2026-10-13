import AVFoundation
import SwiftUI

struct VoiceSettingsView: View {
    static let notificationRowId = "notifications"
    let model: SetupModel

    var body: some View {
        @Bindable var settings = model.voiceSettings
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            Text("Notifications and voice").font(.headline).accessibilityAddTraits(.isHeader)
            if let row = model.sections.flatMap(\.rows).first(where: { $0.id == Self.notificationRowId }) {
                SetupRowView(row: row, isBusy: model.isWorking, perform: model.perform)
            }
            Toggle("Notify when a chat needs you", isOn: $settings.waitingNotices)
            Toggle("Notify when a task completes", isOn: $settings.completedNotices)
            Toggle("Speak announcements", isOn: $settings.speakAnnouncements)
                .onChange(of: settings.speakAnnouncements) { _, enabled in if enabled { model.voiceInteraction() } }
            Text("Speaks chat titles and project names aloud on this Mac.")
                .font(.caption).foregroundStyle(Palette.textSecondary)
            speechControls
            Toggle("Voice commands", isOn: $settings.voiceCommands)
                .onChange(of: settings.voiceCommands) { _, _ in model.voicePolicyChanged() }
            HStack {
                Button("Allow Microphone") { model.requestMicrophone() }
                Button("Allow Speech Recognition") { model.requestSpeechRecognition() }
            }
            Text("Hold ⌃⌥V and say “Porter, show the task”. Release to open it. English only.")
                .font(.caption).foregroundStyle(Palette.textSecondary)
        }
        .onChange(of: settings.quietWhilePaneOpen) { _, _ in model.voicePolicyChanged() }
        .onChange(of: settings.quietWhileLocked) { _, _ in model.voicePolicyChanged() }
        .onChange(of: settings.speakAnnouncements) { _, _ in model.voicePolicyChanged() }
    }

    private var speechControls: some View {
        @Bindable var settings = model.voiceSettings
        return VStack(alignment: .leading, spacing: Tokens.Space.s) {
            Picker("Voice", selection: $settings.voiceIdentifier) {
                Text("System English voice").tag("")
                ForEach(AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }, id: \.identifier) { voice in
                    Text("\(voice.name) (\(voice.language))").tag(voice.identifier)
                }
            }
            Slider(value: $settings.speechRate, in: AVSpeechUtteranceMinimumSpeechRate...AVSpeechUtteranceMaximumSpeechRate) {
                Text("Speaking speed")
            }
            Toggle("Quiet while the pane is open", isOn: $settings.quietWhilePaneOpen)
            Toggle("Quiet while the screen is locked", isOn: $settings.quietWhileLocked)
            HStack {
                Button("Preview voice") { model.previewVoice() }
                Text("English only").font(.caption).foregroundStyle(Palette.textSecondary)
            }
        }
    }
}
