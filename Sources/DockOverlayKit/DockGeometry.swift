import AppKit
import CoreGraphics

/// The screen edge the real Dock is currently reserving space on.
public enum DockEdge: String {
    case bottom, left, right
}

/// The exact screen rectangle the real Dock is reserving on a given edge.
public struct DockReservation: Equatable {
    public let edge: DockEdge
    public let rect: NSRect

    public init(edge: DockEdge, rect: NSRect) {
        self.edge = edge
        self.rect = rect
    }
}

/// Computes the screen rectangle reserved by the real macOS Dock, so the
/// DockSheath overlay window can be sized/positioned to cover it exactly —
/// on whichever edge (bottom, left, or right) the Dock currently occupies.
///
/// This deliberately never hides or repositions the real Dock — it relies on
/// the Dock still being visible, which is what causes macOS to reserve that
/// strip in `NSScreen.visibleFrame` in the first place. Because that
/// reservation is genuine system behavior (not a private-API trick), native
/// window maximize/zoom already respects it with no extra work.
public enum DockGeometry {
    /// Below this inset, a side of the screen is considered "not really
    /// reserved for the Dock" (e.g. Dock auto-hidden).
    public static let minimumHealthyInset: CGFloat = 20

    /// The Dock's current reserved strip on the given screen, or nil if the
    /// Dock isn't reserving space on any edge right now (e.g. auto-hidden).
    ///
    /// `sizeOverride`, when provided, replaces the strip's thickness (height
    /// for a bottom Dock, width for a left/right Dock) while keeping it
    /// anchored to whichever edge was actually detected.
    public static func currentReservation(for screen: NSScreen, sizeOverride: CGFloat? = nil) -> DockReservation? {
        let frame = screen.frame
        let visible = screen.visibleFrame

        // The menu bar always insets the top, independent of the Dock, so it
        // can be isolated and excluded from the left/right strip's height.
        let topInset = max(0, frame.maxY - visible.maxY)
        let bottomInset = max(0, visible.minY - frame.minY)
        let leftInset = max(0, visible.minX - frame.minX)
        let rightInset = max(0, frame.maxX - visible.maxX)

        if bottomInset >= minimumHealthyInset {
            let height = sizeOverride ?? bottomInset
            let rect = NSRect(x: frame.minX, y: frame.minY, width: frame.width, height: height)
            return DockReservation(edge: .bottom, rect: rect)
        }
        if leftInset >= minimumHealthyInset {
            let width = sizeOverride ?? leftInset
            let rect = NSRect(x: frame.minX, y: frame.minY, width: width, height: frame.height - topInset)
            return DockReservation(edge: .left, rect: rect)
        }
        if rightInset >= minimumHealthyInset {
            let width = sizeOverride ?? rightInset
            let rect = NSRect(x: frame.maxX - width, y: frame.minY, width: width, height: frame.height - topInset)
            return DockReservation(edge: .right, rect: rect)
        }
        return nil
    }

    /// Whether the Dock is currently reserving space on any edge (a real,
    /// healthy reservation DockSheath can cover).
    public static func isDockReservationHealthy(for screen: NSScreen) -> Bool {
        currentReservation(for: screen) != nil
    }
}
