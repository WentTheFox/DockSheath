import AppKit
import CoreGraphics

/// The borderless window that visually covers the real Dock, on whichever
/// edge (bottom, left, or right) it's currently on. It never hides or moves
/// the real Dock — it just renders on top of the strip macOS already
/// reserves for it.
public final class OverlayWindow: NSWindow {
    public init(reservation: DockReservation) {
        super.init(contentRect: reservation.rect, styleMask: [.borderless], backing: .buffered, defer: false)
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

    /// Without this, a click on a taskbar button while DockSheath isn't the
    /// active app (the common case — the user is normally focused on
    /// whatever app they're switching away from) only activates/orders the
    /// window front; the click itself isn't delivered to the button, so
    /// activating the button takes a first "wasted" click and a second real
    /// one. Since the overlay window only ever contains DockSheath's own
    /// taskbar chrome, there's no reason a first click shouldn't act on it
    /// directly.
    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
