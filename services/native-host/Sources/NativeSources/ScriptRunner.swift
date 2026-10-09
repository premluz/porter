import Foundation

public enum ScriptError: Error, Equatable {
    /// The user has not allowed Porter to control the application (Automation permission).
    case permissionDenied
    case timedOut
    case failed(String)
}

/// Runs AppleScript and returns its text output. A protocol so connectors can be tested without a browser.
public protocol ScriptRunning: Sendable {
    func run(_ script: String, arguments: [String]) async throws -> String
}

/// Runs scripts with the system's `osascript`, as a child of the app so the permission prompt names Porter,
/// and with a time limit so a stuck browser cannot hang the registry.
public struct OsascriptRunner: ScriptRunning {
    private let timeout: TimeInterval

    public init(timeout: TimeInterval = 5) { self.timeout = timeout }

    public func run(_ script: String, arguments: [String]) async throws -> String {
        let limit = timeout
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do { continuation.resume(returning: try Self.execute(script, arguments, limit)) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }

    private static func execute(_ script: String, _ arguments: [String], _ limit: TimeInterval) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-"] + arguments
        let input = Pipe(), output = Pipe(), failure = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = failure
        do { try process.run() } catch { throw ScriptError.failed("cannot start osascript: \(error)") }
        let watchdog = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + limit, execute: watchdog)
        input.fileHandleForWriting.write(Data(script.utf8))
        try? input.fileHandleForWriting.close()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        let errors = failure.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let timedOut = watchdog.isCancelled == false && process.terminationReason == .uncaughtSignal
        watchdog.cancel()
        guard process.terminationStatus == 0 else {
            let message = String(decoding: errors, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            if timedOut { throw ScriptError.timedOut }
            if message.contains("(-1743)") { throw ScriptError.permissionDenied }
            throw ScriptError.failed(String(message.prefix(300)))
        }
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .newlines)
    }
}
