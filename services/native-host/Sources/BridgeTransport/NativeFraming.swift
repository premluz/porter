import Darwin
import Foundation

public enum FramingError: Error, Equatable, Sendable {
    /// The declared length exceeded the limit; the body was never read.
    case oversized(declared: Int)
    case truncated
    case system(errno: Int32)
}

/// Chrome native messaging framing: a 32-bit length in native byte order, then UTF-8 JSON.
/// The same framing is reused on the local sockets so one codec covers every hop.
public enum NativeFraming {
    private static let prefixLength = MemoryLayout<UInt32>.size

    /// Returns nil on a clean end of stream between frames.
    public static func readFrame(fd: Int32, maximumBytes: Int) throws(FramingError) -> Data? {
        var prefix = [UInt8](repeating: 0, count: prefixLength)
        guard try readExactly(fd, into: &prefix, allowEndOfStream: true) else { return nil }
        let declared = Int(prefix.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) })
        guard declared <= maximumBytes else { throw .oversized(declared: declared) }
        var body = [UInt8](repeating: 0, count: declared)
        if declared > 0 { _ = try readExactly(fd, into: &body, allowEndOfStream: false) }
        return Data(body)
    }

    public static func writeFrame(fd: Int32, _ data: Data) throws(FramingError) {
        var length = UInt32(truncatingIfNeeded: data.count)
        let prefix = withUnsafeBytes(of: &length) { Array($0) }
        try writeAll(fd, prefix + [UInt8](data))
    }

    private static func readExactly(
        _ fd: Int32, into buffer: inout [UInt8], allowEndOfStream: Bool
    ) throws(FramingError) -> Bool {
        var offset = 0
        let total = buffer.count
        while offset < total {
            let count = buffer.withUnsafeMutableBytes { read(fd, $0.baseAddress! + offset, total - offset) }
            if count > 0 {
                offset += count
            } else if count == 0 {
                if offset == 0 && allowEndOfStream { return false }
                throw .truncated
            } else if errno != EINTR {
                throw .system(errno: errno)
            }
        }
        return true
    }

    private static func writeAll(_ fd: Int32, _ bytes: [UInt8]) throws(FramingError) {
        var offset = 0
        while offset < bytes.count {
            let count = bytes.withUnsafeBytes { write(fd, $0.baseAddress! + offset, bytes.count - offset) }
            if count >= 0 {
                offset += count
            } else if errno != EINTR {
                throw .system(errno: errno)
            }
        }
    }
}
