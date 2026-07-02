import AppKit
import CoreGraphics

/// Computes the screen rectangle reserved by the real macOS Dock, so the
/// DockSheath overlay window can be sized/positioned to cover it exactly.
///
/// This deliberately never hides or repositions the real Dock — it relies on
/// the Dock still being visible and bottom-anchored, which is what causes
/// macOS to reserve that strip in `NSScreen.visibleFrame` in the first place.
/// Because that reservation is genuine system behavior (not a private-API
/// trick), native window maximize/zoom already respects it with no extra work.
public enum DockGeometry {
    /// Below this height, the bottom inset is considered "not really the
    /// Dock" (e.g. Dock auto-hidden or moved off the bottom edge).
    public static let minimumHealthyInset: CGFloat = 20

    /// The height, in screen points, currently reserved for the Dock at the
    /// bottom of the given screen. Zero (or near-zero) if the Dock isn't
    /// reserving bottom space right now.
    public static func currentBottomInset(for screen: NSScreen) -> CGFloat {
        max(0, screen.visibleFrame.minY - screen.frame.minY)
    }

    /// The frame the DockSheath overlay window should occupy to exactly
    /// cover the real Dock's reserved area at the bottom of the given screen.
    public static func overlayFrame(for screen: NSScreen, heightOverride: CGFloat? = nil) -> NSRect {
        let height = heightOverride ?? currentBottomInset(for: screen)
        return NSRect(
            x: screen.frame.minX,
            y: screen.frame.minY,
            width: screen.frame.width,
            height: height
        )
    }

    /// Whether the current bottom inset looks like a real, healthy Dock
    /// reservation (Dock visible, bottom-positioned, not auto-hidden).
    public static func isDockReservationHealthy(for screen: NSScreen) -> Bool {
        currentBottomInset(for: screen) >= minimumHealthyInset
    }
}
