import AppKit
import CoreGraphics

/// Converts between the Accessibility API's screen coordinate space (origin
/// top-left of the primary display, y increasing *downward*) and
/// AppKit/Cocoa's screen coordinate space (origin bottom-left of the primary
/// display, y increasing *upward*) that `NSScreen`, `DockReservation`, and
/// the rest of DockSheath use.
///
/// `kAXPositionAttribute`/`kAXSizeAttribute` are always in AX space — a
/// window's on-screen rect read via Accessibility does not line up with an
/// `NSScreen.frame`-based rect (e.g. a taskbar's reserved strip) without this
/// conversion. The transform is a vertical reflection around the primary
/// screen's height, so the same formula converts in either direction.
public enum AXGeometry {
    /// The height used as the reflection axis for `flip(_:primaryScreenHeight:)`.
    public static var primaryScreenHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }

    public static func flip(_ rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.origin.x,
            y: primaryScreenHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }
}
