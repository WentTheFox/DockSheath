import AppKit
import SwiftUI
import DockOverlayKit

/// A `.nonactivatingPanel` doesn't bring the owning app forward just by
/// being clicked — by design, so an accessory panel like this doesn't steal
/// focus from whatever app the user was using. But combined with
/// `NSWindow`'s default `acceptsFirstMouse(for:)` (false), a click landing
/// before the panel is actually key only orders it front/key without
/// delivering that click to whatever's underneath — e.g. the search field —
/// so the user's first click appears to do nothing. Since this panel only
/// ever hosts DockSheath's own quick-launch UI, there's no reason a first
/// click shouldn't act on it directly.
private final class QuickLaunchPanel: NSPanel {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

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

        let panel = QuickLaunchPanel(
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

        var origin: NSPoint
        switch dockEdge {
        case .bottom:
            origin = NSPoint(x: point.x - width / 2, y: point.y)
        case .left:
            origin = NSPoint(x: point.x, y: point.y - height / 2)
        case .right:
            origin = NSPoint(x: point.x - width, y: point.y - height / 2)
        }

        // The anchor point can sit close to a screen edge (e.g. the Start
        // button on a bottom taskbar pinned near the screen's left edge),
        // which centering/side-anchoring alone can push partly off-screen.
        // Clamp back onto whichever screen the anchor point is actually on.
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main {
            let bounds = screen.visibleFrame
            origin.x = min(max(origin.x, bounds.minX + 8), bounds.maxX - width - 8)
            origin.y = min(max(origin.y, bounds.minY + 8), bounds.maxY - height - 8)
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
