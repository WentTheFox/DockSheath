import AppKit
import ApplicationServices
import CoreGraphics

/// A single window belonging to another running application, as seen by
/// DockSheath's taskbar.
public struct RunningWindow: Identifiable {
    public let id: String
    public let pid: pid_t
    public let ownerAppName: String
    public let ownerBundleIdentifier: String?
    public let icon: NSImage?
    /// Read via `kAXTitleAttribute`, so this only needs Accessibility access
    /// (not Screen Recording, unlike `CGWindowListCopyWindowInfo`'s window
    /// name) — see `WindowEnumerationService`. `nil` if the window declines
    /// to report a title via Accessibility.
    public let title: String?
    /// In AppKit/Cocoa screen coordinates (bottom-left origin, y up) —
    /// already converted from the Accessibility API's coordinate space by
    /// `WindowEnumerationService`, so it lines up directly with
    /// `NSScreen.frame`-based rects. `nil` if the window's position/size
    /// couldn't be read.
    public let bounds: CGRect?
    public let isMinimized: Bool
    public let axElement: AXUIElement

    public init(
        id: String,
        pid: pid_t,
        ownerAppName: String,
        ownerBundleIdentifier: String?,
        icon: NSImage?,
        title: String?,
        bounds: CGRect?,
        isMinimized: Bool,
        axElement: AXUIElement
    ) {
        self.id = id
        self.pid = pid
        self.ownerAppName = ownerAppName
        self.ownerBundleIdentifier = ownerBundleIdentifier
        self.icon = icon
        self.title = title
        self.bounds = bounds
        self.isMinimized = isMinimized
        self.axElement = axElement
    }
}

extension RunningWindow {
    /// The screen most of this window's bounds falls on, or `nil` if that
    /// can't be determined — either `bounds` itself is `nil` (Accessibility
    /// declined to report position/size), or its center point doesn't land
    /// on any connected screen. Used to show a running-window button only on
    /// the taskbar instance for the display the window actually lives on.
    public var hostScreen: NSScreen? {
        guard let bounds else { return nil }
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        return NSScreen.screens.first { $0.frame.contains(center) }
    }
}

extension NSScreen {
    /// The Core Graphics display ID backing this screen. Repeated
    /// `NSScreen.screens` calls aren't documented to return the same object
    /// instances for the same physical display, so this is a sturdier way to
    /// compare "is this the same screen" than `NSScreen` object identity —
    /// matching how `SecondaryDisplayManager` already keys its per-screen
    /// taskbar instances.
    public var directDisplayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}

/// Windows grouped by their owning application, for the taskbar's
/// Windows-style grouped display.
public struct RunningAppGroup: Identifiable {
    public let id: pid_t
    public let appName: String
    public let bundleIdentifier: String?
    public let icon: NSImage?
    public var windows: [RunningWindow]

    public init(id: pid_t, appName: String, bundleIdentifier: String?, icon: NSImage?, windows: [RunningWindow]) {
        self.id = id
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.icon = icon
        self.windows = windows
    }
}

extension RunningAppGroup {
    /// A single window's title when there's only one, or "AppName (N)" when
    /// multiple windows are grouped under one button — shared by
    /// `RunningWindowsStripView` and `PinnedAppsStripView` (a pinned app with
    /// open windows renders using the same group it would otherwise get in
    /// the running-windows strip, since the two merge into one button).
    public var taskbarDisplayLabel: String {
        if windows.count == 1, let title = windows[0].title, !title.isEmpty {
            return title
        }
        if windows.count > 1 {
            return "\(appName) (\(windows.count))"
        }
        return appName
    }

    /// The individual title of every window in the group, one per line — the
    /// full detail behind `taskbarDisplayLabel`'s collapsed "AppName (N)"
    /// form.
    public var taskbarTooltip: String {
        guard windows.count > 1 else { return taskbarDisplayLabel }
        return windows
            .map { $0.title?.isEmpty == false ? $0.title! : appName }
            .joined(separator: "\n")
    }
}
