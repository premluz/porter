import ConversationCore
import Foundation

/// A browser with Chrome's scripting dictionary. Adding another Chromium browser is adding a value here,
/// once its dictionary has been checked: only Chrome has been tested.
public struct ChromiumBrowser: Sendable, Equatable {
    public let bundleId: String
    public let displayName: String

    public static let chrome = ChromiumBrowser(bundleId: "com.google.Chrome", displayName: "Chrome")
}

/// The scripts Porter sends a Chromium browser. Both address windows by their `id`: a window reference
/// by position drifts when the order changes, which brought the wrong window forward in testing.
enum ChromiumScripts {
    static let fieldSeparator: Character = "\u{1F}"
    static let recordSeparator: Character = "\u{1E}"

    /// Lists only tabs on the given hosts, so no other address or title leaves the browser. Incognito windows
    /// are skipped. Output: one record per tab, fields window index, window id, active tab index, tab position,
    /// tab id, URL, title.
    static func list(browser: ChromiumBrowser, hosts: [String]) -> String {
        let tests = hosts.map { "(u starts with \"https://\($0)/\")" }.joined(separator: " or ")
        return """
        set fs to character id 31
        set rs to character id 30
        tell application id "\(browser.bundleId)"
            set wids to id of windows
            set modes to mode of windows
            set actives to active tab index of windows
            set urlLists to URL of tabs of windows
            set titleLists to title of tabs of windows
            set idLists to id of tabs of windows
        end tell
        set out to ""
        repeat with wi from 1 to count of wids
            if (item wi of modes) is not "incognito" then
                set us to item wi of urlLists
                repeat with ti from 1 to count of us
                    set u to item ti of us
                    if u is not missing value then
                        if \(tests) then
                            set out to out & wi & fs & (item wi of wids) & fs & (item wi of actives) & fs & ti & fs & (item ti of (item wi of idLists)) & fs & u & fs & (item ti of (item wi of titleLists)) & rs
                        end if
                    end if
                end repeat
            end if
        end repeat
        return out
        """
    }

    /// Arguments: window id, tab id. Prints `ok`, or `gone` when no such tab is in that window.
    static func activate(browser: ChromiumBrowser) -> String {
        """
        on run argv
            set wid to (item 1 of argv) as integer
            set tid to (item 2 of argv) as text
            tell application id "\(browser.bundleId)"
                try
                    set w to window id wid
                on error
                    return "gone"
                end try
                set ids to id of tabs of w
                repeat with i from 1 to count of ids
                    if ((item i of ids) as text) is tid then
                        set active tab index of w to i
                        set index of window id wid to 1
                        activate
                        return "ok"
                    end if
                end repeat
                return "gone"
            end tell
        end run
        """
    }
}
