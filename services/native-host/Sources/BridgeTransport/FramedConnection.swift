import Darwin
import Foundation
import Synchronization

/// One framed stream. Writes may come from any thread (a control request writes to a connector's
/// connection), so they are serialized; reads belong to a single owning thread.
public final class FramedConnection: Sendable {
    public let fd: Int32
    private let writeLock = Mutex<Bool>(false)

    public init(fd: Int32) { self.fd = fd }

    public func send(_ data: Data) throws(FramingError) {
        try writeLock.withLock { closed throws(FramingError) in
            guard !closed else { throw .system(errno: EPIPE) }
            try NativeFraming.writeFrame(fd: fd, data)
        }
    }

    public func receive(maximumBytes: Int) throws(FramingError) -> Data? {
        try NativeFraming.readFrame(fd: fd, maximumBytes: maximumBytes)
    }

    /// Unblocks a reader on another thread; the reader's owner closes the descriptor afterwards.
    public func shutdown() {
        writeLock.withLock { closed in
            if !closed { Darwin.shutdown(fd, SHUT_RDWR) }
            closed = true
        }
    }

    public func closeDescriptor() {
        shutdown()
        Darwin.close(fd)
    }
}
