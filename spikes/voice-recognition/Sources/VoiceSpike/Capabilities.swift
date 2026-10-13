import AVFoundation
import Speech

enum Capabilities {
    static func report(locale: Locale) async {
        let legacy = SFSpeechRecognizer(locale: locale)
        let supported = await SpeechTranscriber.supportedLocale(equivalentTo: locale)
        print("os=\(ProcessInfo.processInfo.operatingSystemVersionString)")
        print("locale=\(locale.identifier)")
        print("speechAuthorization=\(SFSpeechRecognizer.authorizationStatus().rawValue)")
        print("microphoneAuthorization=\(AVCaptureDevice.authorizationStatus(for: .audio).rawValue)")
        print("legacyAvailable=\(legacy?.isAvailable == true)")
        print("legacyOnDevice=\(legacy?.supportsOnDeviceRecognition == true)")
        print("analyzerAvailable=\(SpeechTranscriber.isAvailable)")
        guard let supported else {
            print("analyzerLocale=unsupported")
            return
        }
        let module = SpeechTranscriber(locale: supported, preset: .transcription)
        print("analyzerLocale=\(supported.identifier)")
        print("analyzerAssets=\(await AssetInventory.status(forModules: [module]))")
    }
}
