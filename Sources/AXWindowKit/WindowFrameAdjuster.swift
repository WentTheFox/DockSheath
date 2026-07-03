import CoreGraphics

/// Computes a window frame adjustment to keep windows from sitting under a
/// taskbar's reserved strip on screens where macOS itself doesn't reserve
/// that space (see `DockSheath`'s `SecondaryDisplayManager` — only the
/// screen actually hosting the real Dock gets that for free via
/// `NSScreen.visibleFrame`).
public enum WindowFrameAdjuster {
    /// Given a window's current frame and a taskbar's reserved rect (assumed
    /// flush against one edge of `screenFrame`, as every `DockReservation`
    /// is by construction), returns an adjusted frame that no longer
    /// overlaps the reserved rect, or `nil` if the window doesn't currently
    /// overlap it (no adjustment needed). All three rects must be in the
    /// same coordinate space (AppKit/Cocoa screen coordinates, bottom-left
    /// origin — see `AXGeometry` if converting from Accessibility-API rects).
    ///
    /// The reserved rect's edge is inferred from its position within
    /// `screenFrame` rather than passed explicitly, so this stays a pure
    /// geometry function with no dependency on `DockOverlayKit`'s `DockEdge`.
    public static func adjustedFrame(for windowFrame: CGRect, avoiding reservedRect: CGRect, on screenFrame: CGRect) -> CGRect? {
        guard windowFrame.intersects(reservedRect) else { return nil }

        var adjusted = windowFrame
        if reservedRect.minY <= screenFrame.minY {
            // Flush against the bottom edge — pull the window's bottom up
            // above it, keeping its top edge fixed in place.
            let newMinY = reservedRect.maxY
            adjusted.size.height = max(0, adjusted.maxY - newMinY)
            adjusted.origin.y = newMinY
        } else if reservedRect.minX <= screenFrame.minX {
            // Flush against the left edge — pull the window's left edge in,
            // keeping its right edge fixed in place.
            let newMinX = reservedRect.maxX
            adjusted.size.width = max(0, adjusted.maxX - newMinX)
            adjusted.origin.x = newMinX
        } else if reservedRect.maxX >= screenFrame.maxX {
            // Flush against the right edge — pull the window's right edge
            // in, keeping its left edge fixed in place.
            let newMaxX = reservedRect.minX
            adjusted.size.width = max(0, newMaxX - adjusted.minX)
        }
        return adjusted
    }
}
