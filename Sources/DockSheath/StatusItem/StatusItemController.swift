import AppKit
import DockOverlayKit
import JSON5Config

final class StatusItemController {
    private let statusItem: NSStatusItem
    private let overlayController: OverlayWindowController
    private var dockWarningMenuItem: NSMenuItem?
    private var toggleMenuItem: NSMenuItem?

    /// Called alongside the primary overlay's own toggle, so secondary-screen
    /// taskbars (see `SecondaryDisplayManager`) show/hide together with it.
    var onAdditionalToggle: (() -> Void)?

    init(overlayController: OverlayWindowController) {
        self.overlayController = overlayController
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "dock.rectangle", accessibilityDescription: "DockSheath")
        }

        buildMenu()
    }

    private func buildMenu() {
        let menu = NSMenu()

        let toggleItem = NSMenuItem(
            title: "Hide Taskbar",
            action: #selector(toggleTaskbarVisibility),
            keyEquivalent: ""
        )
        toggleItem.target = self
        menu.addItem(toggleItem)
        toggleMenuItem = toggleItem

        menu.addItem(.separator())

        let editConfigItem = NSMenuItem(
            title: "Edit Config File…",
            action: #selector(editConfigFile),
            keyEquivalent: ""
        )
        editConfigItem.target = self
        menu.addItem(editConfigItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit DockSheath", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    func updateDockHealth(_ diagnosis: DockHealthCheck.Diagnosis) {
        guard let menu = statusItem.menu else { return }

        if let existing = dockWarningMenuItem {
            menu.removeItem(existing)
            dockWarningMenuItem = nil
        }

        guard diagnosis != .healthy, diagnosis != .healthyAutoHide else { return }

        let warningItem = NSMenuItem(
            title: "⚠️ Dock Configuration Issue…",
            action: #selector(showDockWarning),
            keyEquivalent: ""
        )
        warningItem.target = self
        warningItem.representedObject = diagnosis
        menu.insertItem(warningItem, at: 0)
        menu.insertItem(.separator(), at: 1)
        dockWarningMenuItem = warningItem
    }

    @objc private func toggleTaskbarVisibility() {
        overlayController.toggleVisibility()
        onAdditionalToggle?()
        toggleMenuItem?.title = overlayController.isVisible ? "Hide Taskbar" : "Show Taskbar"
    }

    @objc private func editConfigFile() {
        NSWorkspace.shared.open(ConfigStore.shared.configFileURL)
    }

    @objc private func showDockWarning() {
        guard let diagnosis = dockWarningMenuItem?.representedObject as? DockHealthCheck.Diagnosis else { return }

        let alert = NSAlert()
        alert.messageText = "Dock Configuration Issue"
        alert.informativeText = diagnosis.userFacingMessage
        alert.addButton(withTitle: "Open Dock Settings")
        alert.addButton(withTitle: "Fix Automatically")
        alert.addButton(withTitle: "Cancel")

        NSApp.activate(ignoringOtherApps: true)
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            if let url = URL(string: "x-apple.systempreferences:com.apple.Dock-Settings.extension") {
                NSWorkspace.shared.open(url)
            }
        case .alertSecondButtonReturn:
            let confirm = NSAlert()
            confirm.messageText = "Change Dock Settings?"
            confirm.informativeText = "This will turn off Dock auto-hide and restart the Dock process."
            confirm.addButton(withTitle: "Change Settings")
            confirm.addButton(withTitle: "Cancel")
            if confirm.runModal() == .alertFirstButtonReturn {
                DockHealthCheck.applyCompatibleDockSettings()
            }
        default:
            break
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
