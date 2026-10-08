import Darwin
import Foundation

public enum SocketError: Error, Equatable, Sendable {
    case pathTooLong(String)
    case insecureDirectory(String)
    case alreadyRunning(String)
    case foreignPeer(uid: UInt32)
    case system(String, errno: Int32)
}

/// Same-user local sockets. Access control is the 0700 directory plus a peer uid check on every
/// accept; code-signature validation of the peer belongs to the signed-helper work (TASK-027).
public enum UnixSocket {
    private static let directoryMode: mode_t = 0o700
    private static let socketMode: mode_t = 0o600
    private static let backlog: Int32 = 8

    public static func listen(path: String) throws(SocketError) -> Int32 {
        try prepareDirectory(for: path)
        try removeStaleSocket(at: path)
        let fd = try makeSocket()
        var address = try makeAddress(path)
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard bound == 0, chmod(path, socketMode) == 0, Darwin.listen(fd, backlog) == 0 else {
            let code = errno
            close(fd)
            throw .system("bind \(path)", errno: code)
        }
        return fd
    }

    public static func connect(path: String) throws(SocketError) -> Int32 {
        let fd = try makeSocket()
        var address = try makeAddress(path)
        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard result == 0 else {
            let code = errno
            close(fd)
            throw .system("connect \(path)", errno: code)
        }
        return fd
    }

    /// Refuses any peer that is not the same user, before a single byte is read.
    public static func accept(listener: Int32) throws(SocketError) -> Int32 {
        var fd: Int32
        repeat { fd = Darwin.accept(listener, nil, nil) } while fd < 0 && errno == EINTR
        guard fd >= 0 else { throw .system("accept", errno: errno) }
        var uid: uid_t = 0
        var gid: gid_t = 0
        guard getpeereid(fd, &uid, &gid) == 0 else {
            let code = errno
            close(fd)
            throw .system("getpeereid", errno: code)
        }
        guard uid == geteuid() else {
            close(fd)
            throw .foreignPeer(uid: uid)
        }
        return fd
    }

    private static func makeSocket() throws(SocketError) -> Int32 {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw .system("socket", errno: errno) }
        var enabled: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &enabled, socklen_t(MemoryLayout<Int32>.size))
        return fd
    }

    private static func makeAddress(_ path: String) throws(SocketError) -> sockaddr_un {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let capacity = MemoryLayout.size(ofValue: address.sun_path)
        guard path.utf8.count < capacity else { throw .pathTooLong(path) }
        withUnsafeMutableBytes(of: &address.sun_path) { buffer in
            buffer.copyBytes(from: path.utf8)
            buffer[path.utf8.count] = 0
        }
        return address
    }

    private static func prepareDirectory(for socketPath: String) throws(SocketError) {
        let directory = (socketPath as NSString).deletingLastPathComponent
        if mkdir(directory, directoryMode) != 0 && errno != EEXIST { throw .system("mkdir \(directory)", errno: errno) }
        var info = stat()
        guard stat(directory, &info) == 0 else { throw .system("stat \(directory)", errno: errno) }
        guard info.st_uid == geteuid(), info.st_mode & 0o077 == 0 else { throw .insecureDirectory(directory) }
    }

    private static func removeStaleSocket(at path: String) throws(SocketError) {
        guard access(path, F_OK) == 0 else { return }
        if let probe = try? connect(path: path) {
            close(probe)
            throw .alreadyRunning(path)
        }
        unlink(path)
    }
}
