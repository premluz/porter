import CoreGraphics
import Foundation
import Synchronization
@testable import NativeSources

/// A synthetic accessibility element. Titles in tests are neutral placeholders, never real chats.
final class FakeNode: AccessibilityNode {
    let role: String
    let label: String
    let frame: CGRect?
    let children: [any AccessibilityNode]
    private let pressable: Bool
    private let onPress: (@Sendable (String) -> Void)?

    init(
        _ role: String, _ label: String = "", frame: CGRect? = CGRect(x: 20, y: 0, width: 200, height: 20),
        pressable: Bool = true, children: [FakeNode] = [], onPress: (@Sendable (String) -> Void)? = nil
    ) {
        self.role = role
        self.label = label
        self.frame = frame
        self.children = children
        self.pressable = pressable
        self.onPress = onPress
    }

    func press() -> Bool {
        guard pressable else { return false }
        onPress?("\(role):\(label)")
        return true
    }
}

/// An element in the left sidebar strip.
func side(_ role: String, _ label: String, onPress: (@Sendable (String) -> Void)? = nil, children: [FakeNode] = []) -> FakeNode {
    FakeNode(role, label, children: children, onPress: onPress)
}

/// An element in the middle of the window, where messages are. No adapter may read it.
func centre(_ role: String, _ label: String) -> FakeNode {
    FakeNode(role, label, frame: CGRect(x: 700, y: 0, width: 400, height: 20))
}

func fakeWindow(_ children: [FakeNode]) -> FakeNode {
    FakeNode("AXWindow", "Window", frame: CGRect(x: 0, y: 0, width: 1800, height: 1000), pressable: false, children: children)
}

final class FakeAccessibility: AccessibilityProviding {
    private struct State {
        var trusted = true
        var running = true
        var hasWindow = true
        var presses: [String] = []
        var forwarded: [String] = []
    }

    private let state = Mutex(State())
    private let tree: @Sendable (@escaping @Sendable (String) -> Void) -> FakeNode

    /// `tree` builds the window given a press recorder, so a test can see what was pressed.
    init(tree: @escaping @Sendable (@escaping @Sendable (String) -> Void) -> FakeNode) { self.tree = tree }

    var presses: [String] { state.withLock { $0.presses } }
    var forwarded: [String] { state.withLock { $0.forwarded } }
    func set(trusted: Bool? = nil, running: Bool? = nil, hasWindow: Bool? = nil) {
        state.withLock {
            if let trusted { $0.trusted = trusted }
            if let running { $0.running = running }
            if let hasWindow { $0.hasWindow = hasWindow }
        }
    }

    var isTrusted: Bool { state.withLock { $0.trusted } }
    func isRunning(bundleId: String) -> Bool { state.withLock { $0.running } }
    func bringForward(bundleId: String) { state.withLock { $0.forwarded.append(bundleId) } }

    func withWindow<Result: Sendable>(
        bundleId: String, _ body: @escaping @Sendable (any AccessibilityNode) throws -> Result
    ) async throws -> Result {
        let (trusted, running, hasWindow) = state.withLock { ($0.trusted, $0.running, $0.hasWindow) }
        guard trusted else { throw AccessibilityError.notTrusted }
        guard running else { throw AccessibilityError.notRunning }
        guard hasWindow else { throw AccessibilityError.noWindow }
        let record: @Sendable (String) -> Void = { [self] press in state.withLock { $0.presses.append(press) } }
        return try body(tree(record))
    }
}
