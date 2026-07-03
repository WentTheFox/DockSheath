import AppKit
import CoreGraphics
import DockOverlayKit
import AXWindowKit
import JSON5Config

/// Renders an additional taskbar on every connected screen besides the one
/// hosting the real Dock, when `behavior.showOnAllDisplays` is enabled.
///
/// Those screens have no OS-level reservation to cover — macOS only ever
/// reserves `visibleFrame` space for the Dock's actual screen — so unlike
/// the primary taskbar (which relies entirely on that reservation), this
/// also has to actively watch for windows that have been placed under its
/// reserved strip and pull them back above it. There's no lightweight
/// per-window "moved/resized" notification available without a per-window
/// `AXObserver` (a heavier mechanism the rest of `AXWindowKit` deliberately
/// defers post-MVP too — see `RunningWindowsStripView`'s own polling
/// fallback), so this polls on a similar cadence instead.
final class SecondaryDisplayManager {
    private var primaryScreen: NSScreen
    private var instances: [CGDirectDisplayID: TaskbarInstance] = [:]
    private var isEnabled = false
    private var lastConfig: TaskbarConfig?
    private let windowService = WindowEnumerationService()
    private var enforcementTimer: Timer?

    private static let enforcementInterval: TimeInterval = 1.0

    /// The screen actually reserving space for the real Dock right now, or
    /// a reasonable fallback (the menu-bar screen) when the Dock is
    /// auto-hidden and so isn't reserving space anywhere to detect.
    static func detectPrimaryDockScreen() -> NSScreen {
        NSScreen.screens.first(where: { DockGeometry.currentReservation(for: $0) != nil })
            ?? NSScreen.screens.first
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }

    init(primaryScreen: NSScreen) {
        self.primaryScreen = primaryScreen
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        enforcementTimer?.invalidate()
    }

    func apply(config: TaskbarConfig) {
        lastConfig = config
        isEnabled = config.behavior.showOnAllDisplays
        rebuildInstances()
        for instance in instances.values {
            instance.apply(config: config)
        }
        updateEnforcementTimer()
    }

    func toggleVisibility() {
        for instance in instances.values {
            instance.toggleVisibility()
        }
    }

    @objc private func screenParametersDidChange() {
        primaryScreen = Self.detectPrimaryDockScreen()
        rebuildInstances()
        if let lastConfig {
            for instance in instances.values {
                instance.apply(config: lastConfig)
            }
        }
        updateEnforcementTimer()
    }

    private func rebuildInstances() {
        guard isEnabled, let primaryID = Self.displayID(for: primaryScreen) else {
            instances.removeAll()
            return
        }

        let secondaryScreens = NSScreen.screens.filter { screen in
            Self.displayID(for: screen) != primaryID && DockGeometry.currentReservation(for: screen) == nil
        }
        let currentIDs = Set(secondaryScreens.compactMap(Self.displayID(for:)))

        for id in instances.keys where !currentIDs.contains(id) {
            instances.removeValue(forKey: id)
        }

        for screen in secondaryScreens {
            guard let id = Self.displayID(for: screen), instances[id] == nil else { continue }
            let edge = DockGeometry.dockOrientationPreference() ?? .bottom
            let instance = TaskbarInstance(screen: screen, reservationStrategy: .fixed(edge: edge))
            instances[id] = instance
            instance.start()
        }
    }

    private func updateEnforcementTimer() {
        enforcementTimer?.invalidate()
        enforcementTimer = nil
        guard isEnabled, !instances.isEmpty else { return }
        enforcementTimer = Timer.scheduledTimer(withTimeInterval: Self.enforcementInterval, repeats: true) { [weak self] _ in
            self?.enforceWindowBoundaries()
        }
    }

    /// Pulls any window that's drifted under a secondary taskbar's reserved
    /// strip back above/beside it. Only touches windows actually sitting on
    /// a managed secondary screen — the primary screen's real Dock already
    /// handles this for free via `visibleFrame`.
    private func enforceWindowBoundaries() {
        guard !instances.isEmpty else { return }

        let reservedStrips: [(screen: NSScreen, rect: CGRect)] = instances.values.compactMap { instance in
            guard let screen = instance.overlay.window.screen else { return nil }
            return (screen, instance.overlay.window.frame)
        }
        guard !reservedStrips.isEmpty else { return }

        let windows = windowService.enumerateGroups().flatMap(\.windows)
        for window in windows where !window.isMinimized {
            guard let bounds = window.bounds else { continue }
            guard let strip = reservedStrips.first(where: { $0.screen.frame.contains(CGPoint(x: bounds.midX, y: bounds.midY)) }) else {
                continue
            }
            guard let adjusted = WindowFrameAdjuster.adjustedFrame(for: bounds, avoiding: strip.rect, on: strip.screen.frame) else {
                continue
            }
            AccessibilityWindowController.setFrame(window, to: adjusted)
        }
    }

    private static func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}
