import BridgeTransport
import ConversationCore
import Darwin
import Foundation

// Development registry daemon. The Mac app embeds the same RegistryService; this executable lets the
// bridge be exercised before the app exists.

private func log(_ message: String) {
    FileHandle.standardError.write(Data("\(Date().formatted(.iso8601)) \(message)\n".utf8))
}

let service = RegistryService(
    deviceId: UUID(),
    log: { log($0) },
    focusApplication: { ChromeFocus.requestForeground() }
)

do {
    try service.start(bridgePath: PorterPaths.bridgeSocket(), controlPath: PorterPaths.controlSocket())
} catch {
    log("cannot start: \(error)")
    exit(1)
}
log("listening on \(PorterPaths.supportDirectory())")
signal(SIGPIPE, SIG_IGN)
dispatchMain()
