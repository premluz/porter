import AppKit
import PorterMacKit

// Porter [--fixtures] [--self-test]
//   --fixtures   show sample conversations instead of the live registry
//   --self-test  build the panel off screen, check it, and exit; never shows a window
//   --probe-animation  open the real panel once and measure its animation from its own pixels;
//                      shows the panel at the screen edge for about a second
//   --probe-controls <bundle id> [seconds]  list the buttons of that app that appear or disappear over the
//                      time; run it while the app is writing a reply. Prints labels of buttons only.

let arguments = Set(CommandLine.arguments.dropFirst())
let application = NSApplication.shared
application.setActivationPolicy(.accessory)

if arguments.contains("--probe-animation") {
    Task { @MainActor in exit(await AnimationProbe.run() ? 0 : 1) }
    application.run()
} else if let flag = CommandLine.arguments.firstIndex(of: "--probe-controls"), CommandLine.arguments.indices.contains(flag + 1) {
    let bundleId = CommandLine.arguments[flag + 1]
    let seconds = CommandLine.arguments.indices.contains(flag + 2) ? Int(CommandLine.arguments[flag + 2]) ?? 60 : 60
    Task {
        print(await ControlProbeCommand.run(bundleId: bundleId, seconds: seconds))
        exit(0)
    }
    application.run()
} else if arguments.contains("--self-test") {
    Task { exit(await SelfTest.run() ? 0 : 1) }
    application.run()
} else {
    let delegate = AppDelegate(mode: arguments.contains("--fixtures") ? .fixtures : .live)
    application.delegate = delegate
    application.run()
}
