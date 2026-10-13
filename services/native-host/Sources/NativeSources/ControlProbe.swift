import Foundation

/// Finds which controls of a desktop app come and go over time, to learn what the app shows while it is generating
/// (a "Stop" button, say). Run by hand while a reply is being written; it is a diagnostic and nothing in the app uses it.
/// Only the labels of buttons outside the sidebar strip are looked at, and only the ones that are not there in every
/// sample are printed, cut short, so the conversation itself (static text) is never read or shown.
public enum ControlProbe {
    private static let roles: Set<String> = ["AXButton", "AXCheckBox", "AXRadioButton", "AXMenuButton", "AXPopUpButton"]
    static let labelLimit = 40
    static let maximumNodes = 6_000

    /// The controls of one window outside the sidebar strip, as "role label".
    static func controls(in window: any AccessibilityNode, stripWidth: CGFloat) -> Set<String> {
        guard let origin = window.frame?.minX else { return [] }
        var found = Set<String>()
        var visited = 0
        func visit(_ node: any AccessibilityNode, depth: Int) {
            guard visited < maximumNodes, depth < 40 else { return }
            visited += 1
            if roles.contains(node.role), !node.label.isEmpty, let frame = node.frame, frame.minX > origin + stripWidth {
                found.insert("\(node.role) \(node.label.prefix(labelLimit))")
            }
            for child in node.children { visit(child, depth: depth + 1) }
        }
        visit(window, depth: 0)
        return found
    }

    /// What changed across the samples: each control that was in some samples and not in all, with how many had it.
    static func changing(_ samples: [Set<String>]) -> [(control: String, present: Int)] {
        guard let first = samples.first else { return [] }
        let all = samples.reduce(into: first) { $0.formUnion($1) }
        return all.compactMap { control in
            let present = samples.filter { $0.contains(control) }.count
            return present < samples.count ? (control, present) : nil
        }.sorted { ($0.present, $0.control) < ($1.present, $1.control) }
    }

    /// Samples the app's front window every `interval` for `duration`, and returns a printable report.
    public static func run(
        accessibility: any AccessibilityProviding = LiveAccessibility(), bundleId: String,
        duration: Duration, interval: Duration = .seconds(2)
    ) async -> String {
        guard accessibility.isTrusted else { return "Porter is not allowed under Accessibility; allow it and run again." }
        var samples: [Set<String>] = []
        let end = ContinuousClock.now + duration
        while ContinuousClock.now < end {
            do {
                samples.append(try await accessibility.withWindow(bundleId: bundleId) { controls(in: $0, stripWidth: 300) })
            } catch {
                return "Could not read \(bundleId): \(error)"
            }
            try? await Task.sleep(for: interval)
        }
        var lines = ["\(samples.count) samples; \(samples.last?.count ?? 0) controls in the last one."]
        let changes = changing(samples)
        lines.append(changes.isEmpty ? "No control came or went." : "Controls that came or went (present in N of \(samples.count) samples):")
        lines += changes.prefix(60).map { "  \($0.present)  \($0.control)" }
        return lines.joined(separator: "\n")
    }
}
