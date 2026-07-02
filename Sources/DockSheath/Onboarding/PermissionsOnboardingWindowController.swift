import AppKit
import SwiftUI

final class PermissionsOnboardingWindowController: NSWindowController {
    private let status = PermissionsStatus()

    convenience init(onContinue: @escaping () -> Void) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "DockSheath Setup"
        window.center()
        window.isReleasedWhenClosed = false

        self.init(window: window)

        let view = PermissionsOnboardingView(status: status) { [weak self] in
            self?.close()
            onContinue()
        }
        window.contentViewController = NSHostingController(rootView: view)
    }

    func showAndActivate() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
