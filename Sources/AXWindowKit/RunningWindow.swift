import AppKit
import ApplicationServices

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
