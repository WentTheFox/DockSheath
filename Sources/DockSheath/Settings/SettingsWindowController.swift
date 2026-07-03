import AppKit
import SwiftUI

/// Hosts `SettingsView` in a standard titled window — reachable from the
/// status item's menu whether or not the taskbar is actually running yet
/// (see `StatusItemController`), since it just edits `config.json5` through
/// `ConfigStore` and doesn't depend on Accessibility access.
final class SettingsWindowController: NSWindowController {
    private let model = SettingsModel()

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "DockSheath Settings"
        window.center()
        window.isReleasedWhenClosed = false

        self.init(window: window)

        window.contentViewController = NSHostingController(rootView: SettingsView(model: model))
    }

    func showAndActivate(selecting tab: SettingsTab? = nil) {
        if let tab {
            model.selectedTab = tab
        }
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
