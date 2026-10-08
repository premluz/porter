import AppKit
import PorterMacKit

// Porter [--fixtures] [--self-test]
//   --fixtures   show sample conversations instead of the live registry
//   --self-test  build the panel off screen, check it, and exit; never shows a window

let arguments = Set(CommandLine.arguments.dropFirst())
let application = NSApplication.shared
application.setActivationPolicy(.accessory)

if arguments.contains("--self-test") {
    Task { exit(await SelfTest.run() ? 0 : 1) }
    application.run()
} else {
    let delegate = AppDelegate(mode: arguments.contains("--fixtures") ? .fixtures : .live)
    application.delegate = delegate
    application.run()
}
