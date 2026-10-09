import AppKit
import UniformTypeIdentifiers

/// The menu-bar fallback, so Porter stays reachable if the edge position is inconvenient.
@MainActor
public final class StatusItemController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let controller: PanelController
    private let setup: SetupWindowController
    private let notes: [String]

    public init(controller: PanelController, setup: SetupWindowController, notes: [String]) {
        self.controller = controller
        self.setup = setup
        self.notes = notes
        super.init()
        if let button = item.button {
            if let symbol = NSImage(systemSymbolName: "rectangle.stack", accessibilityDescription: "Porter") {
                button.image = symbol
            } else {
                button.title = "Porter"
            }
        }
        rebuildMenu()
    }

    @objc private func openPane() { controller.open() }

    @objc private func openSetup() { setup.show() }

    @objc private func chooseEdge(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let edge = PanelEdge(rawValue: raw) else { return }
        controller.setEdge(edge)
        rebuildMenu()
    }

    /// A packet is a file the user picks; Porter reads nothing it was not handed.
    @objc private func openPacket() {
        let chooser = NSOpenPanel()
        chooser.allowedContentTypes = [.json]
        chooser.allowsMultipleSelection = false
        chooser.message = "Choose a context packet from Atlas, Manager or Memento"
        NSApp.activate()
        guard chooser.runModal() == .OK, let url = chooser.url else { return }
        controller.model.importPacket(from: url)
        controller.open()
    }

    @objc private func quit() { NSApp.terminate(nil) }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Porter (⌃⌥Space)", action: #selector(openPane), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Open context packet…", action: #selector(openPacket), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Set up Porter…", action: #selector(openSetup), keyEquivalent: ""))
        menu.addItem(.separator())
        for edge in PanelEdge.allCases {
            let entry = NSMenuItem(title: "\(edge.rawValue.capitalized) edge", action: #selector(chooseEdge), keyEquivalent: "")
            entry.representedObject = edge.rawValue
            entry.state = controller.settings.edge == edge ? .on : .off
            menu.addItem(entry)
        }
        for note in notes {
            menu.addItem(.separator())
            let line = NSMenuItem(title: note, action: nil, keyEquivalent: "")
            line.isEnabled = false
            menu.addItem(line)
        }
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Porter", action: #selector(quit), keyEquivalent: "q"))
        for entry in menu.items where entry.action != nil { entry.target = self }
        item.menu = menu
    }
}
