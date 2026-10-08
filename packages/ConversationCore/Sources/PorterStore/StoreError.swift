import Foundation

public enum StoreError: Error, Equatable, Sendable {
    /// `context` names the operation so a failure in a log is traceable without the SQL text.
    case sqlite(code: Int32, message: String, context: String)
    case newerThanSupported(found: Int, supported: Int)
    case invalidKey(String)
    case fileProtection(path: String, reason: String)
}
