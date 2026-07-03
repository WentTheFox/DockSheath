import AppKit
import ApplicationServices

/// Enumerates windows across running applications for the taskbar.
///
/// Existence, minimized state, title, and geometry all come from the
/// Accessibility API (`AXUIElement`), which only requires Accessibility
/// permission — reading `kAXTitleAttribute` does not require Screen
/// Recording access, unlike `CGWindowListCopyWindowInfo`'s window name,
/// so DockSheath doesn't need that additional permission for MVP.
public final class WindowEnumerationService {
    public init() {}

    public func enumerateGroups() -> [RunningAppGroup] {
        let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }

        var groups: [RunningAppGroup] = []
        for app in apps {
            let appWindows = windows(for: app)
            guard !appWindows.isEmpty else { continue }
            groups.append(
                RunningAppGroup(
                    id: app.processIdentifier,
                    appName: app.localizedName ?? "Unknown",
                    bundleIdentifier: app.bundleIdentifier,
                    icon: app.icon,
                    windows: appWindows
                )
            )
        }
        return groups
    }

    public func windows(for app: NSRunningApplication) -> [RunningWindow] {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        guard let windowsValue = copyAttribute(appElement, kAXWindowsAttribute),
              let axWindows = windowsValue as? [AXUIElement] else {
            return []
        }

        return axWindows.enumerated().map { index, axWindow in
            makeRunningWindow(axWindow: axWindow, app: app, index: index)
        }
    }

    private func makeRunningWindow(axWindow: AXUIElement, app: NSRunningApplication, index: Int) -> RunningWindow {
        let title = stringAttribute(axWindow, kAXTitleAttribute)
        let isMinimized = boolAttribute(axWindow, kAXMinimizedAttribute) ?? false
        let bounds = boundsAttribute(axWindow)

        return RunningWindow(
            id: "\(app.processIdentifier)-\(index)",
            pid: app.processIdentifier,
            ownerAppName: app.localizedName ?? "Unknown",
            ownerBundleIdentifier: app.bundleIdentifier,
            icon: app.icon,
            title: title,
            bounds: bounds,
            isMinimized: isMinimized,
            axElement: axWindow
        )
    }

    private func copyAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value
    }

    private func stringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        copyAttribute(element, attribute) as? String
    }

    private func boolAttribute(_ element: AXUIElement, _ attribute: String) -> Bool? {
        copyAttribute(element, attribute) as? Bool
    }

    /// Returns the window's frame in AppKit/Cocoa screen coordinates
    /// (bottom-left origin, y up) — not the raw Accessibility-API coordinate
    /// space (top-left origin, y down) `kAXPositionAttribute`/
    /// `kAXSizeAttribute` report in, which doesn't line up with
    /// `NSScreen.frame`-based rects like a taskbar's reserved strip. See
    /// `AXGeometry`.
    private func boundsAttribute(_ element: AXUIElement) -> CGRect? {
        guard let positionValue = copyAttribute(element, kAXPositionAttribute),
              let sizeValue = copyAttribute(element, kAXSizeAttribute),
              CFGetTypeID(positionValue) == AXValueGetTypeID(),
              CFGetTypeID(sizeValue) == AXValueGetTypeID() else {
            return nil
        }

        var origin = CGPoint.zero
        var size = CGSize.zero
        // swiftlint:disable:next force_cast
        AXValueGetValue(positionValue as! AXValue, .cgPoint, &origin)
        // swiftlint:disable:next force_cast
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        let axRect = CGRect(origin: origin, size: size)
        return AXGeometry.flip(axRect, primaryScreenHeight: AXGeometry.primaryScreenHeight)
    }
}
