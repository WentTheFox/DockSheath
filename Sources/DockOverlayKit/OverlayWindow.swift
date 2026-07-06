import AppKit
import CoreGraphics

/// The borderless window that visually covers the real Dock, on whichever
/// edge (bottom, left, or right) it's currently on. It never hides or moves
/// the real Dock — it just renders on top of the strip macOS already
/// reserves for it.
///
/// An `NSPanel` with `.nonactivatingPanel` rather than a plain `NSWindow`:
/// without that, a taskbar click is a normal "activating" click — it both
/// delivers the mouseDown to the button *and* brings DockSheath itself to
/// the front, exactly like clicking any ordinary app's window. That
/// self-activation fires `NSWorkspace.didActivateApplicationNotification`
/// for DockSheath, which `RunningWindowsStripView` used to wire straight to
/// a full button rebuild — destroying the very `TaskbarButton` (mid-click,
/// before `mouseUp`) the user's mouse was still down on, silently losing
/// the click. `.nonactivatingPanel` lets the window become key and receive
/// clicks normally without ever activating the owning app, so a taskbar
/// click no longer triggers that self-activation at all.
public final class OverlayWindow: NSPanel {
    public init(reservation: DockReservation) {
        super.init(contentRect: reservation.rect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        configure()
    }

    private func configure() {
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        isMovableByWindowBackground = false
        level = Self.dockCoveringLevel
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
    }

    /// Resolved at runtime (never hardcoded) since the Dock's raw window
    /// level can shift across macOS versions.
    public static var dockCoveringLevel: NSWindow.Level {
        let dockLevel = CGWindowLevelForKey(.dockWindow)
        return NSWindow.Level(rawValue: Int(dockLevel) + 1)
    }

    public func reposition(to reservation: DockReservation) {
        setFrame(reservation.rect, display: true)
    }

    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { false }

    /// DockSheath is essentially never the actual foreground app during
    /// normal use — the whole point is glancing at/clicking the taskbar
    /// while some other app stays frontmost — so without this, AppKit's own
    /// internal drawing code (which many controls/materials/template icons
    /// consult via these two properties to decide whether to render their
    /// "active" or dimmed "inactive window" appearance) would treat the
    /// taskbar as permanently inactive-looking. Overriding the getters (not
    /// `canBecomeKey`/`canBecomeMain`, which control whether this window is
    /// *allowed* to actually become key/main) only changes what this
    /// window's own view hierarchy sees when it asks "am I key/main right
    /// now" for drawing purposes — it doesn't touch `NSApp.keyWindow`/
    /// `.mainWindow` or actual keyboard routing, which the window server
    /// tracks independently of what a window reports about itself here.
    public override var isKeyWindow: Bool { true }
    public override var isMainWindow: Bool { true }
}
