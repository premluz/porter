import AppKit
import CoreGraphics
import Foundation
import PorterStore
import Synchronization

/// Measures the real opening animation from inside it: SwiftUI hands the interpolated size of the glass
/// shape to a recorder on every frame. The panel is shown at the screen edge for about a second, so it
/// is run on request (`Porter --probe-animation`), never as part of the automated checks.
@MainActor
public enum AnimationProbe {
    private static let settleWait: UInt64 = 1_000_000_000
    private static let displayedMilliseconds = 700

    struct Sample: Sendable {
        let milliseconds: Int
        let width: Int
        let height: Int
    }

    public static func run() async -> Bool {
        guard let controller = try? await makeController() else {
            print("FAIL  could not build the panel")
            return false
        }
        controller.show()
        try? await Task.sleep(nanoseconds: 400_000_000)
        let capsule = controller.frame(expanded: false)
        let pane = controller.frame(expanded: true)
        let recording = Recording()
        controller.presentation.recorder = { rect in recording.add(rect) }
        recording.begin()
        let before = ContinuousClock.now
        controller.open()
        let blocked = before.duration(to: .now)
        print("open() blocked the main thread for \(Int(blocked.components.seconds * 1_000 + blocked.components.attoseconds / 1_000_000_000_000_000)) ms")
        try? await Task.sleep(nanoseconds: settleWait)
        controller.presentation.recorder = nil
        controller.close()
        try? await Task.sleep(nanoseconds: settleWait)
        return report(recording.samples, capsuleWidth: Int(capsule.width), paneWidth: Int(pane.width))
    }

    /// Written from SwiftUI's animation thread and read after the move, so access is locked.
    private final class Recording: Sendable {
        private struct State {
            var start = ContinuousClock.now
            var samples: [Sample] = []
        }
        private let state = Mutex(State())

        var samples: [Sample] { state.withLock { $0.samples } }

        func begin() { state.withLock { $0 = State() } }

        func add(_ rect: CGRect) {
            state.withLock { state in
                let elapsed = state.start.duration(to: .now)
                let milliseconds = Int(elapsed.components.seconds * 1_000 + elapsed.components.attoseconds / 1_000_000_000_000_000)
                let width = Int(rect.width.rounded()), height = Int(rect.height.rounded())
                if let last = state.samples.last, last.width == width, last.height == height { return }
                state.samples.append(Sample(milliseconds: milliseconds, width: width, height: height))
            }
        }
    }

    private static func makeController() async throws -> PanelController {
        let store = try PreferenceStore(path: PreferenceStore.inMemoryPath, deviceId: UUID())
        let model = AppModel(source: FixtureSource(), store: store, performer: WorkspaceRecoveryPerformer())
        await model.refresh()
        let defaults = UserDefaults(suiteName: "porter.probe.\(UUID().uuidString)") ?? .standard
        return PanelController(model: model, settings: PanelSettings(), defaults: defaults)
    }

    private static func report(_ samples: [Sample], capsuleWidth: Int, paneWidth: Int) -> Bool {
        print("ms    width x height   (capsule \(capsuleWidth) pt wide, pane \(paneWidth) pt wide)")
        for sample in samples where sample.milliseconds <= displayedMilliseconds { print(String(format: "%4d  %4d x %4d", sample.milliseconds, sample.width, sample.height)) }
        let opening = Array(samples.prefix { $0.milliseconds < 900 })
        let widths = opening.map(\.width)
        let between = Set(widths.filter { $0 > capsuleWidth + 8 && $0 < paneWidth - 8 })
        let final = widths.last ?? 0
        let peak = widths.max() ?? 0
        let smooth = between.count >= 4
        let settles = abs(final - paneWidth) <= 2
        print("distinct sizes between capsule and pane: \(between.count)  \(smooth ? "PASS" : "FAIL")  (needs 4 or more to count as a smooth growth)")
        print("settles at the pane width (\(final) vs \(paneWidth)):  \(settles ? "PASS" : "FAIL")")
        print("overshoot beyond the pane width: \(max(peak - paneWidth, 0)) pt (information only)")
        return smooth && settles
    }
}
