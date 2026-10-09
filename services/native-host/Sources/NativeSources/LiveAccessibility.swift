import AppKit
import ApplicationServices
import Foundation

/// An element of a running app, read through the system's Accessibility interface.
struct LiveNode: AccessibilityNode {
    let element: AXUIElement

    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }

    private func text(_ name: String) -> String {
        ((Self.attribute(element, name) as? String) ?? "").replacingOccurrences(of: "\n", with: " ")
    }

    var role: String { text(kAXRoleAttribute) }

    var label: String {
        [text(kAXTitleAttribute), text(kAXDescriptionAttribute), text(kAXValueAttribute)].first { !$0.isEmpty } ?? ""
    }

    var frame: CGRect? {
        guard let position = Self.attribute(element, kAXPositionAttribute), let size = Self.attribute(element, kAXSizeAttribute),
              CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        var extent = CGSize.zero
        // Both type ids were checked above, so these casts are AXValue to AXValue.
        guard AXValueGetValue(position as! AXValue, .cgPoint, &point), AXValueGetValue(size as! AXValue, .cgSize, &extent) else { return nil }
        return CGRect(origin: point, size: extent)
    }

    var children: [any AccessibilityNode] {
        ((Self.attribute(element, kAXChildrenAttribute) as? [AXUIElement]) ?? []).map { LiveNode(element: $0) }
    }

    func press() -> Bool {
        var current: AXUIElement? = element
        for _ in 0..<6 {
            guard let candidate = current else { return false }
            var names: CFArray?
            if AXUIElementCopyActionNames(candidate, &names) == .success, (names as? [String])?.contains(kAXPressAction) == true {
                return AXUIElementPerformAction(candidate, kAXPressAction as CFString) == .success
            }
            current = Self.attribute(candidate, kAXParentAttribute).map { $0 as! AXUIElement }
        }
        return false
    }
}

/// Reads real applications. All accessibility calls run on one serial queue, because they block on the other app.
public final class LiveAccessibility: AccessibilityProviding {
    private let queue = DispatchQueue(label: "porter.accessibility", qos: .userInitiated)

    public init() {}

    public var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows the system's permission prompt (once) and returns whether Porter is already trusted.
    public static func requestTrust() -> Bool {
        // The documented value of kAXTrustedCheckOptionPrompt, which Swift 6 will not let a global be read for.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    public func isRunning(bundleId: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).isEmpty
    }

    public func bringForward(bundleId: String) {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first?.activate()
    }

    public func withWindow<Result: Sendable>(
        bundleId: String, _ body: @escaping @Sendable (any AccessibilityNode) throws -> Result
    ) async throws -> Result {
        guard AXIsProcessTrusted() else { throw AccessibilityError.notTrusted }
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first else { throw AccessibilityError.notRunning }
        let pid = app.processIdentifier
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                let application = AXUIElementCreateApplication(pid)
                // Chromium-based apps build their accessibility tree only when asked.
                AXUIElementSetAttributeValue(application, "AXManualAccessibility" as CFString, kCFBooleanTrue)
                var windows: CFTypeRef?
                guard AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &windows) == .success,
                      let main = (windows as? [AXUIElement])?.first else {
                    continuation.resume(throwing: AccessibilityError.noWindow)
                    return
                }
                do { continuation.resume(returning: try body(LiveNode(element: main))) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }
}
