import BridgeTransport
import Darwin
import Foundation

// Launched by Chrome, one process per extension connection. It forwards frames between Chrome's
// stdio and the registry socket without interpreting them; the registry decides what they mean.

private let chromeInput: Int32 = 0
private let chromeOutput: Int32 = 1
private let chromeToHostLimit = 64 * 1024
private let hostToChromeLimit = 1024 * 1024
private let failureStatus: Int32 = 2

private func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("porter-native-host: \(message)\n".utf8))
    exit(failureStatus)
}

/// Chrome passes the caller's origin as the first argument. The file is written at install time,
/// so a missing file fails closed instead of admitting every extension.
private func requireAllowedOrigin() {
    guard CommandLine.arguments.count >= 2 else { fail("missing caller origin argument") }
    let origin = CommandLine.arguments[1]
    let path = PorterPaths.allowedOriginsFile()
    guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else {
        fail("cannot read allowed origins at \(path); run the install script")
    }
    let allowed = contents.split(whereSeparator: \.isNewline).map(String.init)
    guard allowed.contains(origin) else { fail("origin \(origin) is not allowed") }
}

signal(SIGPIPE, SIG_IGN)
requireAllowedOrigin()

let upstream: FramedConnection
do {
    upstream = FramedConnection(fd: try UnixSocket.connect(path: PorterPaths.bridgeSocket()))
} catch {
    fail("registry unreachable: \(error)")
}

let downstream = Thread {
    do {
        while let frame = try upstream.receive(maximumBytes: hostToChromeLimit) {
            try NativeFraming.writeFrame(fd: chromeOutput, frame)
        }
    } catch {
        FileHandle.standardError.write(Data("porter-native-host: registry to Chrome failed: \(error)\n".utf8))
    }
    exit(0)
}
downstream.start()

do {
    while let frame = try NativeFraming.readFrame(fd: chromeInput, maximumBytes: chromeToHostLimit) {
        try upstream.send(frame)
    }
} catch {
    FileHandle.standardError.write(Data("porter-native-host: Chrome to registry failed: \(error)\n".utf8))
}
upstream.shutdown()
exit(0)
