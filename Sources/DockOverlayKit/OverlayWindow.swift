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
}
