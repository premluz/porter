import Darwin
import Foundation
import Testing
@testable import BridgeTransport

@Suite("Native messaging framing and local sockets")
struct TransportTests {
    private func pipeFDs() -> (read: Int32, write: Int32) {
        var fds: [Int32] = [0, 0]
        #expect(pipe(&fds) == 0)
        return (fds[0], fds[1])
    }

    private func privateDirectory() throws -> String {
        let path = NSTemporaryDirectory() + "porter-\(UInt32.random(in: 0...UInt32.max))"
        #expect(mkdir(path, 0o700) == 0)
        return path
    }

    @Test("a frame round-trips with a native-order length prefix")
    func roundTrip() throws {
        let (reader, writer) = pipeFDs()
        try NativeFraming.writeFrame(fd: writer, Data(#"{"a":1}"#.utf8))
        #expect(try NativeFraming.readFrame(fd: reader, maximumBytes: 64) == Data(#"{"a":1}"#.utf8))
    }

    @Test("a declared length over the limit is refused before the body is read")
    func oversizedRefusedEarly() throws {
        let (reader, writer) = pipeFDs()
        var declared = UInt32(10_000)
        _ = withUnsafeBytes(of: &declared) { write(writer, $0.baseAddress, 4) }
        #expect(throws: FramingError.oversized(declared: 10_000)) {
            try NativeFraming.readFrame(fd: reader, maximumBytes: 64)
        }
    }

    @Test("clean end of stream is nil; a cut-off frame is an error")
    func endOfStream() throws {
        let (reader, writer) = pipeFDs()
        close(writer)
        #expect(try NativeFraming.readFrame(fd: reader, maximumBytes: 64) == nil)
        let (cutReader, cutWriter) = pipeFDs()
        var declared = UInt32(8)
        _ = withUnsafeBytes(of: &declared) { write(cutWriter, $0.baseAddress, 4) }
        _ = write(cutWriter, "abc", 3)
        close(cutWriter)
        #expect(throws: FramingError.truncated) { try NativeFraming.readFrame(fd: cutReader, maximumBytes: 64) }
    }

    @Test("a socket in a private directory accepts a same-user peer and is mode 0600")
    func sameUserPeer() throws {
        let path = try privateDirectory() + "/s.sock"
        let listener = try UnixSocket.listen(path: path)
        let client = try UnixSocket.connect(path: path)
        let server = try UnixSocket.accept(listener: listener)
        var info = stat()
        #expect(stat(path, &info) == 0)
        #expect(info.st_mode & 0o777 == 0o600)
        for fd in [client, server, listener] { close(fd) }
    }

    @Test("a directory readable by others is refused")
    func insecureDirectory() throws {
        let directory = try privateDirectory()
        #expect(chmod(directory, 0o755) == 0)
        #expect(throws: SocketError.insecureDirectory(directory)) { try UnixSocket.listen(path: directory + "/s.sock") }
    }

    @Test("a live socket blocks a second daemon; a dead one is replaced")
    func staleAndLive() throws {
        let path = try privateDirectory() + "/s.sock"
        let first = try UnixSocket.listen(path: path)
        #expect(throws: SocketError.alreadyRunning(path)) { try UnixSocket.listen(path: path) }
        close(first)
        let second = try UnixSocket.listen(path: path)
        close(second)
    }

    @Test("an over-long path is rejected rather than truncated")
    func pathTooLong() {
        let path = "/tmp/" + String(repeating: "a", count: 200)
        #expect(throws: SocketError.pathTooLong(path)) { try UnixSocket.connect(path: path) }
    }
}
