import ConversationCore
import Darwin
import Foundation
@testable import BridgeTransport

/// Plays Chrome: launches the real relay binary with the origin argument and speaks native
/// messaging frames over its stdin/stdout.
final class FakeChrome {
    static let origin = "chrome-extension://abcdefghijklmnopabcdefghijklmnop/"

    let installationId = UUID()
    let epoch: String
    private let process = Process()
    private let input = Pipe()
    private let output = Pipe()
    private var sequence = 0
    var connectorId: String { BridgeCoordinator.connectorId(for: installationId) }

    /// SwiftPM links the build products under .build/debug; the test target depends on the
    /// executable so `swift test` rebuilds it first.
    static func relayExecutable() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: ".build/debug/porter-native-host").standardizedFileURL
    }

    init(supportDirectory: String, origin: String = FakeChrome.origin, epoch: String = "epoch-1") throws {
        self.epoch = epoch
        process.executableURL = Self.relayExecutable()
        process.arguments = [origin]
        process.environment = [PorterPaths.supportDirectoryVariable: supportDirectory]
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
    }

    var isRunning: Bool { process.isRunning }

    func waitForExit(timeout: TimeInterval) -> Int32? {
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.01) }
        return process.isRunning ? nil : process.terminationStatus
    }

    func send(type: String, payload: String, connectorId: String? = nil, sequence explicit: Int? = nil) throws {
        let number = explicit ?? sequence
        sequence = number + 1
        let json = """
        {"protocolVersion":"1.0","messageId":"\(UUID().uuidString)","connectorId":"\(connectorId ?? self.connectorId)",\
        "connectionEpoch":"\(epoch)","sequence":\(number),"type":"\(type)","sentAt":"2026-10-08T07:00:00Z","payload":\(payload)}
        """
        try NativeFraming.writeFrame(fd: input.fileHandleForWriting.fileDescriptor, Data(json.utf8))
    }

    func hello(alias: String) throws {
        try send(type: "hello", payload: #"{"installationId":"\#(installationId.uuidString)","profileAlias":"\#(alias)","adapterVersions":{"claude":"0.1.0"}}"#)
    }

    func snapshot(tabId: Int, windowId: Int, chat: String, title: String) throws {
        let tab = #"{"tabId":\#(tabId),"windowId":\#(windowId),"provider":"claude","providerConversationId":"\#(chat)","title":"\#(title)","canonicalUrl":"https://claude.ai/chat/\#(chat)"}"#
        try send(type: "inventory.snapshot", payload: #"{"tabs":[\#(tab)]}"#)
    }

    /// Next registry message, or nil if none arrives in time or the relay ended.
    func receive(timeout: TimeInterval = 3) -> BridgeMessage? {
        var descriptor = pollfd(fd: output.fileHandleForReading.fileDescriptor, events: Int16(POLLIN), revents: 0)
        guard poll(&descriptor, 1, Int32(timeout * 1000)) > 0,
              let frame = try? NativeFraming.readFrame(fd: descriptor.fd, maximumBytes: 1 << 20) else { return nil }
        return try? EnvelopeDecoder.decodeMessage(frame)
    }

    func terminate() {
        input.fileHandleForWriting.closeFile()
        if process.isRunning { process.terminate() }
    }
}
