import AppKit
import ApplicationServices

/// Performs window actions (activate, minimize, close) against a specific
/// window's `AXUIElement`, driven from taskbar button clicks.
public enum AccessibilityWindowController {
    public static func activate(_ window: RunningWindow) {
        if window.isMinimized {
            AXUIElementSetAttributeValue(window.axElement, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }
        AXUIElementPerformAction(window.axElement, kAXRaiseAction as CFString)
        NSRunningApplication(processIdentifier: window.pid)?.activate(options: [.activateIgnoringOtherApps])
    }

    public static func minimize(_ window: RunningWindow) {
        AXUIElementSetAttributeValue(window.axElement, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
    }

    /// Moves/resizes a window to `frame`, given in AppKit/Cocoa screen
    /// coordinates (bottom-left origin, y up) — converted to the
    /// Accessibility API's coordinate space (top-left origin, y down)
    /// before writing. See `AXGeometry`. Used to pull windows out from
    /// under a taskbar's reserved strip on screens without a real Dock,
    /// where nothing at the OS level keeps them from overlapping it.
    public static func setFrame(_ window: RunningWindow, to frame: CGRect) {
        let axRect = AXGeometry.flip(frame, primaryScreenHeight: AXGeometry.primaryScreenHeight)
        var position = axRect.origin
        var size = axRect.size
        guard let positionValue = AXValueCreate(.cgPoint, &position),
              let sizeValue = AXValueCreate(.cgSize, &size) else {
            return
        }
        AXUIElementSetAttributeValue(window.axElement, kAXPositionAttribute as CFString, positionValue)
        AXUIElementSetAttributeValue(window.axElement, kAXSizeAttribute as CFString, sizeValue)
    }

    /// The click behavior shared by any single taskbar button representing a
    /// whole app group — used both by `RunningWindowsStripView` and by
    /// `PinnedAppsStripView` once a pinned app has open windows and its
    /// button merges with the running one. Minimizes every window in the
    /// group if it's already frontmost and none are minimized, otherwise
    /// raises/activates the first window (matching how clicking a Dock icon
    /// behaves).
    public static func activateOrMinimize(_ group: RunningAppGroup, frontmostPID: pid_t?) {
        guard let firstWindow = group.windows.first else { return }
        let isFrontmost = group.id == frontmostPID
        let anyMinimized = group.windows.contains { $0.isMinimized }

        if isFrontmost && !anyMinimized {
            group.windows.forEach(minimize)
        } else {
            activate(firstWindow)
        }
    }

    public static func close(_ window: RunningWindow) {
        var closeButtonValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            window.axElement,
            kAXCloseButtonAttribute as CFString,
            &closeButtonValue
        )
        guard result == .success,
              let closeButtonValue,
              CFGetTypeID(closeButtonValue) == AXUIElementGetTypeID() else {
            return
        }
        // swiftlint:disable:next force_cast
        let closeButton = closeButtonValue as! AXUIElement
        AXUIElementPerformAction(closeButton, kAXPressAction as CFString)
    }
}
