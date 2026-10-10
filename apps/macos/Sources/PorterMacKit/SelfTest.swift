import AppKit
import Foundation
import PorterPanelModel
import PorterStore
import SwiftUI

/// Headless smoke test of the AppKit layer: builds the real panel and views off screen, drives the
/// state machine, and compares real window frames with the geometry. It never orders a window
/// front, so it is safe to run while you work. A pass is not a visual review.
@MainActor
public enum SelfTest {
    public static func run() async -> Bool {
        var failures: [String] = []
        func check(_ name: String, _ condition: Bool) {
            print("\(condition ? "PASS" : "FAIL")  \(name)")
            if !condition { failures.append(name) }
        }
        do {
            let store = try PreferenceStore(path: PreferenceStore.inMemoryPath, deviceId: UUID())
            try await SampleData.seedPins(into: store, at: Date())
            let model = AppModel(source: FixtureSource(), store: store, performer: WorkspaceRecoveryPerformer())
            await model.refresh()
            let defaults = try ephemeralDefaults()
            let controller = PanelController(model: model, settings: PanelSettings(), defaults: defaults)
            checkModel(model, check)
            checkPanel(controller, check)
            let floating = PanelController(
                model: model, settings: PanelSettings(mode: .floating, floatCenter: CGPoint(x: 0.4, y: 0.5)), defaults: defaults
            )
            checkGeometry(floating, "floating", check)
            let lying = PanelController(
                model: model, settings: PanelSettings(mode: .floating, floatCenter: CGPoint(x: 0.5, y: 0.99)), defaults: defaults
            )
            lying.orientation = .horizontal
            checkGeometry(lying, "floating, lying down", check)
            checkHotKey(check)
        } catch {
            check("setup (\(error))", false)
        }
        print(failures.isEmpty ? "self test passed" : "self test FAILED: \(failures.joined(separator: "; "))")
        return failures.isEmpty
    }

    private static func checkModel(_ model: AppModel, _ check: (String, Bool) -> Void) {
        check("fixture list has several items", model.items.count >= 7)
        check("an ambiguous item exists", model.items.contains { $0.isAmbiguous })
        check("a closed pin and an offline pin exist", model.snapshot.pinned.count == 2)
    }

    private static func checkPanel(_ controller: PanelController, _ check: (String, Bool) -> Void) {
        checkGeometry(controller, "docked", check)
        controller.panel.contentView?.layoutSubtreeIfNeeded()
        check("SwiftUI content lays out", (controller.panel.contentView?.subviews.count ?? 0) > 0)
        checkSetupLayout(check)
        if let item = controller.model.items.first {
            let size = NSHostingView(rootView: ItemRowView(item: item, isSelected: false, activate: {})).fittingSize
            check("a pane row lays out at least row height (\(size))", size.height >= Tokens.Size.rowHeight - 1 && size.width > 0)
            let label = NSHostingView(rootView: TooltipView(item: item)).fittingSize
            check("a capsule label lays out within its maximum width (\(label))", label.width > 0 && label.width <= Tokens.Size.tooltipMaximumWidth && label.height > 0)
        }
    }

    /// The window at rest is exactly the resting shape (the tab with its flares, or the capsule), the open window is the
    /// pane, and the shape keeps its place on the screen when the pane opens round it. Run for each way of resting.
    static func checkGeometry(_ controller: PanelController, _ label: String, _ check: (String, Bool) -> Void) {
        let visible = controller.visibleFrame
        let rest = controller.frame(expanded: false)
        let restWindow = controller.layout.restWindow(in: visible)
        let pane = controller.frame(expanded: true)
        controller.applyInstantly(expanded: false)
        check("\(label): window matches the resting shape (window \(controller.panel.frame), expected \(restWindow))", controller.panel.frame == restWindow)
        check("\(label): the resting shape is slim, not the size of the pane", min(rest.width, rest.height) <= Tokens.Size.capsuleWidth && rest.width * rest.height < pane.width * pane.height)
        controller.applyInstantly(expanded: true)
        check("\(label): window matches pane geometry (window \(controller.panel.frame), expected \(pane))", controller.panel.frame == pane)
        let local = controller.presentation.rest.rect
        check("\(label): the resting shape keeps its screen position inside the pane window",
              local.minX + pane.minX == rest.minX && pane.maxY - local.maxY == rest.minY)
        check("\(label): presentation shows the pane when expanded", controller.presentation.isExpanded)
        controller.applyInstantly(expanded: false)
        check("\(label): collapsing returns to the resting window (window \(controller.panel.frame), expected \(restWindow))", controller.panel.frame == restWindow)
    }

    /// The setup window's content must size itself from its rows, with every state present.
    private static func checkSetupLayout(_ check: (String, Bool) -> Void) {
        let inputs = SetupInputs(
            chrome: .permissionDenied, claudeApp: .ready, chatgptApp: .notRunning,
            installedEditors: ["VS Code"], claudeCodeHook: false
        )
        let model = SetupModel(performer: WorkspaceRecoveryPerformer()) { inputs }
        let size = NSHostingView(rootView: SetupView(model: model)).fittingSize
        check("setup window lays out at its width (\(size))", size.width == Tokens.Size.setupWidth && size.height > Tokens.Size.setupIcon * 4)
    }

    private static func checkHotKey(_ check: (String, Bool) -> Void) {
        let keys = GlobalHotKey.controlOptionSpace
        let registered = (try? GlobalHotKey(keyCode: keys.keyCode, modifiers: keys.modifiers, action: {})) != nil
        check("global shortcut ⌃⌥Space can be registered (fails if another app owns it)", registered)
    }

    private static func ephemeralDefaults() throws -> UserDefaults {
        let name = "porter.selftest.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: name) else { throw SelfTestError.noDefaults }
        return defaults
    }

    private enum SelfTestError: Error { case noDefaults }
}
