import Darwin
import Foundation

public struct ProcessRecord: Sendable, Equatable {
    public let pid: Int32
    public let parent: Int32
    /// The terminal device the process runs on, as `ttys003`, or nil when it has none.
    public let tty: String?
    public let executablePath: String?

    public init(pid: Int32, parent: Int32, tty: String?, executablePath: String?) {
        self.pid = pid
        self.parent = parent
        self.tty = tty
        self.executablePath = executablePath
    }
}

public protocol ProcessTable: Sendable {
    func record(for pid: Int32) -> ProcessRecord?
}

/// Finds out, from beside a coding agent, which terminal it runs in and which application hosts that terminal, by
/// walking up its parents. A hook runs as the agent's descendant, so the answer is the agent's own.
public enum TerminalProbe {
    public struct Placement: Sendable, Equatable {
        public let tty: String?
        public let hostApp: String?
    }

    private static let maximumDepth = 16

    /// `bundleId` turns an application's folder into its bundle identifier.
    public static func probe(
        from pid: Int32, table: any ProcessTable, bundleId: @Sendable (String) -> String?
    ) -> Placement {
        var tty: String?
        var host: String?
        var current = pid
        var seen: Set<Int32> = []
        for _ in 0..<maximumDepth {
            guard current > 1, seen.insert(current).inserted, let record = table.record(for: current) else { break }
            if tty == nil { tty = record.tty }
            if host == nil, let path = record.executablePath, let range = path.range(of: ".app/") {
                host = bundleId(String(path[..<range.lowerBound]) + ".app")
            }
            current = record.parent
        }
        return Placement(tty: tty, hostApp: host)
    }

    /// The bundle identifier in an application's Info.plist.
    public static func bundleIdentifier(ofApplicationAt path: String) -> String? {
        Bundle(path: path)?.bundleIdentifier
    }
}

/// The real process table, from the kernel.
public struct LiveProcessTable: ProcessTable {
    public init() {}

    public func record(for pid: Int32) -> ProcessRecord? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0) == 0, size > 0 else { return nil }
        return ProcessRecord(
            pid: pid, parent: info.kp_eproc.e_ppid, tty: Self.ttyName(info.kp_eproc.e_tdev), executablePath: Self.path(of: pid)
        )
    }

    private static func ttyName(_ device: dev_t) -> String? {
        guard device != -1, let name = devname(device, S_IFCHR) else { return nil }
        return String(cString: name)
    }

    private static func path(of pid: Int32) -> String? {
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        return length > 0 ? String(cString: buffer) : nil
    }
}
