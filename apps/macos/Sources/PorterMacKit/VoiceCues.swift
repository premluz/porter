import AppKit

@MainActor final class VoiceCues: NSObject, NSSoundDelegate {
    private let startSound = NSSound(contentsOfFile: "/System/Library/Sounds/Tink.aiff", byReference: true)
    private let stopSound = NSSound(contentsOfFile: "/System/Library/Sounds/Morse.aiff", byReference: true)
    private var startFinished: ((Bool) -> Void)?

    func playStart(then finish: @escaping (Bool) -> Void) -> Bool {
        guard let startSound else { return false }
        stopSound?.stop()
        startSound.currentTime = 0
        startFinished = finish
        startSound.delegate = self
        guard startSound.play() else {
            startFinished = nil
            return false
        }
        return true
    }

    func cancelStart() {
        startFinished = nil
        startSound?.stop()
    }

    func playStop() -> Bool {
        guard let stopSound else { return false }
        stopSound.currentTime = 0
        return stopSound.play()
    }

    func sound(_ sound: NSSound, didFinishPlaying finished: Bool) {
        guard sound === startSound else { return }
        let callback = startFinished
        startFinished = nil
        callback?(finished)
    }
}
