import Foundation

/// The two terminals Porter can bring a specific session forward in, found by the terminal device each tab runs on.
/// Both scripts are written from each application's scripting dictionary and have not been run against the real
/// applications yet; the connector reports a failure plainly if they do not work.
enum TerminalScripts {
    static let terminal = "com.apple.Terminal"
    static let iTerm = "com.googlecode.iterm2"
    static let fieldSeparator: Character = "\u{1F}"
    static let recordSeparator: Character = "\u{1E}"

    static func supportsTabFocus(_ bundleId: String) -> Bool { bundleId == terminal || bundleId == iTerm }

    /// Output: one record per tab, `tty` then the tab's title. Titles are display text only.
    static func titles(for bundleId: String) -> String? {
        switch bundleId {
        case terminal:
            return """
            set fs to character id 31
            set rs to character id 30
            set out to ""
            tell application id "\(terminal)"
                repeat with w in windows
                    repeat with t in tabs of w
                        set label to custom title of t
                        if label is "" then set label to name of w
                        set out to out & (tty of t) & fs & label & rs
                    end repeat
                end repeat
            end tell
            return out
            """
        case iTerm:
            return """
            set fs to character id 31
            set rs to character id 30
            set out to ""
            tell application id "\(iTerm)"
                repeat with w in windows
                    repeat with t in tabs of w
                        repeat with s in sessions of t
                            set out to out & (tty of s) & fs & (name of s) & rs
                        end repeat
                    end repeat
                end repeat
            end tell
            return out
            """
        default:
            return nil
        }
    }

    /// Argument: the terminal device, such as `ttys003`. Prints `ok`, or `gone` when no tab runs on it.
    static func focus(bundleId: String) -> String? {
        switch bundleId {
        case terminal:
            return """
            on run argv
                set target to "/dev/" & (item 1 of argv)
                tell application id "\(terminal)"
                    repeat with w in windows
                        repeat with t in tabs of w
                            if (tty of t) is target then
                                set selected tab of w to t
                                set frontmost of w to true
                                activate
                                return "ok"
                            end if
                        end repeat
                    end repeat
                end tell
                return "gone"
            end run
            """
        case iTerm:
            return """
            on run argv
                set target to "/dev/" & (item 1 of argv)
                tell application id "\(iTerm)"
                    repeat with w in windows
                        repeat with t in tabs of w
                            repeat with s in sessions of t
                                if (tty of s) is target then
                                    tell w to select
                                    tell t to select
                                    tell s to select
                                    activate
                                    return "ok"
                                end if
                            end repeat
                        end repeat
                    end repeat
                end tell
                return "gone"
            end run
            """
        default:
            return nil
        }
    }

    /// `tty` records parsed from a titles script's output; the device is normalised to `ttys003` form.
    static func parseTitles(_ output: String) -> [String: String] {
        var result: [String: String] = [:]
        for record in output.split(separator: recordSeparator, omittingEmptySubsequences: true) {
            let fields = record.split(separator: fieldSeparator, maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2 else { continue }
            let device = fields[0].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "/dev/", with: "")
            let title = fields[1].trimmingCharacters(in: .whitespacesAndNewlines)
            if !device.isEmpty, !title.isEmpty { result[device] = title }
        }
        return result
    }
}
