import AppKit
import SwiftUI

/// A borderless panel anchored above the taskbar's Start button, hosting the
/// SwiftUI quick-launch/search view.
public final class QuickLaunchWindowController: NSWindowController {
    private var panel: NSPanel { window as! NSPanel }

    public init(onLaunch: @escaping (InstalledApp) -> Void, onPin: ((InstalledApp) -> Void)? = nil) {
        let apps = InstalledAppsIndex.scan()
        let hostingController = NSHostingController(
            rootView: QuickLaunchSearchView(allApps: apps, onLaunch: onLaunch, onPin: onPin)
        )

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 420),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = hostingController
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false

        super.init(window: panel)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Shows the panel anchored just above the given screen point (typically
    /// the top-center of the taskbar's Start button).
    public func show(anchoredAbove point: NSPoint) {
        guard let contentView = panel.contentView else { return }
        let size = contentView.fittingSize
        let origin = NSPoint(x: point.x - size.width / 2, y: point.y)
        panel.setFrame(NSRect(origin: origin, size: NSSize(width: 420, height: max(size.height, 420))), display: true)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func hide() {
        panel.orderOut(nil)
    }

    public var isVisible: Bool { panel.isVisible }
}
