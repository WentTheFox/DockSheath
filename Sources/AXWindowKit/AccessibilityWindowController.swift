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
