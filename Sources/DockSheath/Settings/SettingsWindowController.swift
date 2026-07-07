import AppKit
import SwiftUI

/// Hosts `SettingsView` in a standard titled window — reachable from the
/// status item's menu whether or not the taskbar is actually running yet
/// (see `StatusItemController`), since it just edits `config.json5` through
/// `ConfigStore` and doesn't depend on Accessibility access.
final class SettingsWindowController: NSWindowController {
    private let model = SettingsModel()

    /// Forwarded straight to `model` — set by `AppDelegate` right after
    /// construction, same as `showAndActivate(selecting:)` sets
    /// `model.selectedTab`.
    var onCheckForUpdatesNow: (() -> Void)? {
        get { model.onCheckForUpdatesNow }
        set { model.onCheckForUpdatesNow = newValue }
    }

    convenience init() {
        // Wide enough that all 5 tabs' labels fit in the native tab strip —
        // narrower than this (the previous 520pt), SwiftUI's macOS TabView
        // collapses the tabs that don't fit behind a ">>" overflow button
        // instead of just wrapping/shrinking them.
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
            styleMask: [.titled, .closable, .resizable],
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
