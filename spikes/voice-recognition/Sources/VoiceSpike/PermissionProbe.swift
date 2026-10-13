import AppKit
import AVFoundation
import Speech

@MainActor
final class PermissionProbe: NSObject {
    private static var retained: PermissionProbe?
    private let window = NSWindow()
    private let status = NSTextField(labelWithString: "")
    private let spacing: CGFloat = 16
    private let width: CGFloat = 480
    private let height: CGFloat = 320
    private let comparisonLocale = "en-US"

    static func show() {
        let probe = PermissionProbe()
        retained = probe
        probe.present()
    }

    private func present() {
        NSApplication.shared.setActivationPolicy(.regular)
        window.title = "Porter recognition permission spike"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: width, height: height))
        let speech = NSButton(title: "Request Speech Recognition", target: self, action: #selector(requestSpeech))
        let microphone = NSButton(title: "Request Microphone", target: self, action: #selector(requestMicrophone))
        let britishAssets = NSButton(title: "Install en-GB recognizer assets", target: self, action: #selector(installBritishAssets))
        let americanAssets = NSButton(title: "Install en-US recognizer assets", target: self, action: #selector(installAmericanAssets))
        let quit = NSButton(title: "Quit", target: NSApplication.shared, action: #selector(NSApplication.terminate(_:)))
        let stack = NSStackView(views: [status, speech, microphone, britishAssets, americanAssets, quit])
        stack.orientation = .vertical
        stack.spacing = spacing
        window.contentView = stack
        refresh()
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate()
    }

    @objc private func requestSpeech() {
        SFSpeechRecognizer.requestAuthorization { _ in
            Task { @MainActor in self.refresh() }
        }
    }

    @objc private func requestMicrophone() {
        AVCaptureDevice.requestAccess(for: .audio) { _ in
            Task { @MainActor in self.refresh() }
        }
    }

    @objc private func installBritishAssets() {
        installAssets(locale: Locale(identifier: SpikeConfiguration.defaultLocale))
    }

    @objc private func installAmericanAssets() {
        installAssets(locale: Locale(identifier: comparisonLocale))
    }

    private func installAssets(locale: Locale) {
        Task {
            do {
                guard let supported = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
                    throw SpikeError.invalid("Unsupported locale: \(locale.identifier)")
                }
                let module = SpeechTranscriber(locale: supported, preset: .transcription)
                if let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
                    try await request.downloadAndInstall()
                }
                status.stringValue = "\(locale.identifier) assets: \(await AssetInventory.status(forModules: [module]))"
            } catch {
                status.stringValue = "Asset installation failed: \(error)"
            }
        }
    }

    private func refresh() {
        status.stringValue = "Speech: \(SFSpeechRecognizer.authorizationStatus().rawValue); microphone: \(AVCaptureDevice.authorizationStatus(for: .audio).rawValue)"
    }
}
