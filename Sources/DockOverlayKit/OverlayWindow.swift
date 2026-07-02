import AppKit
import CoreGraphics

/// The borderless window that visually covers the real Dock at the bottom of
/// the screen. It never hides or moves the real Dock — it just renders on
/// top of the strip macOS already reserves for it.
public final class OverlayWindow: NSWindow {
    public init(screen: NSScreen) {
        let frame = DockGeometry.overlayFrame(for: screen)
        // `contentRect` is in global screen coordinates, so this still lands
        // on the right screen even without disambiguating via `screen:` —
        // which matters here because the `screen:`-taking initializer is a
        // convenience initializer, and subclass `init` must call a
        // designated one.
        super.init(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
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

    public func reposition(for screen: NSScreen, heightOverride: CGFloat? = nil) {
        setFrame(DockGeometry.overlayFrame(for: screen, heightOverride: heightOverride), display: true)
    }

    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { false }
}
