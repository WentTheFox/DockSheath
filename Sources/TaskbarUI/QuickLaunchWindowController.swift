import AppKit
import SwiftUI
import DockOverlayKit

/// A borderless panel anchored next to the taskbar's Start button — above it
/// for a bottom Dock, to the side of it for a left/right Dock — hosting the
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

    /// Shows the panel anchored next to the given screen point (typically a
    /// point on the edge of the taskbar's Start button facing away from the
    /// Dock), oriented to open away from the given Dock edge.
    public func show(near point: NSPoint, dockEdge: DockEdge) {
        guard let contentView = panel.contentView else { return }
        let size = contentView.fittingSize
        let width = max(size.width, 420)
        let height = max(size.height, 420)

        let origin: NSPoint
        switch dockEdge {
        case .bottom:
            origin = NSPoint(x: point.x - width / 2, y: point.y)
        case .left:
            origin = NSPoint(x: point.x, y: point.y - height / 2)
        case .right:
            origin = NSPoint(x: point.x - width, y: point.y - height / 2)
        }

        panel.setFrame(NSRect(origin: origin, size: NSSize(width: width, height: height)), display: true)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func hide() {
        panel.orderOut(nil)
    }

    public var isVisible: Bool { panel.isVisible }
}
