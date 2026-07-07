import AppKit
import AXWindowKit
import JSON5Config

/// The taskbar strip listing running application windows — grouped one
/// button per app by default, or one button per window when `groupByApp` is
/// false. Refreshes on app launch/terminate/activate notifications plus a
/// coarse fallback poll for same-app window open/close (a fully
/// AXObserver-driven live refresh is a post-MVP improvement). `rebuildButtons()`
/// diffs against `lastRenderedState` before touching the stack view, so a
/// poll tick that finds nothing visually different is a no-op rather than a
/// visible flicker.
public final class RunningWindowsStripView: NSView {
    /// A memoized representation of the last set of buttons actually built,
    /// so `rebuildButtons()` can skip tearing down and recreating every
    /// button when a poll/notification-driven `refresh()` finds nothing
    /// visually different — the common case, since most of the time windows
    /// just sit stationary between polls. `isGrouped` disambiguates a
    /// grouped-app button from a per-window button that would otherwise
    /// render identically (a single-window app, with `groupByApp` toggled),
    /// so switching that setting always still forces a real rebuild.
    private struct RenderedButtonState: Equatable {
        let isGrouped: Bool
        let icon: NSImage?
        let title: String
        let tooltip: String?
        let isHighlighted: Bool
        let showsLabel: Bool
        let iconSize: CGFloat

        /// `icon` compares by reference, not by pixel content — `app.icon`
        /// is stable/cached across polls for an unchanged running app, and a
        /// deep image compare would be needlessly expensive here anyway.
        /// `title`/`tooltip` compare by value instead, since AX attribute
        /// reads produce a fresh `String` instance every poll even when the
        /// text itself hasn't changed. `iconSize` is compared too, since it's
        /// baked into the button at construction time (see `TaskbarButton
        /// .init`) rather than being adjustable after the fact — without it
        /// here, changing the icon-size setting would look like "nothing
        /// visually changed" and the stale-sized buttons would never rebuild.
        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.isGrouped == rhs.isGrouped
                && lhs.icon === rhs.icon
                && lhs.title == rhs.title
                && lhs.tooltip == rhs.tooltip
                && lhs.isHighlighted == rhs.isHighlighted
                && lhs.showsLabel == rhs.showsLabel
                && lhs.iconSize == rhs.iconSize
        }
    }

    private let stackView = NSStackView()
    private var orientationConstraints: [NSLayoutConstraint] = []
    private let service = WindowEnumerationService()
    private var groups: [RunningAppGroup] = []
    private var lastRenderedState: [RenderedButtonState] = []
    private var pollTimer: Timer?
    public var refreshIntervalSeconds: TimeInterval = 1.5 {
        didSet { restartPolling() }
    }

    public var orientation: NSUserInterfaceLayoutOrientation = .horizontal {
        didSet {
            guard oldValue != orientation else { return }
            applyOrientation()
        }
    }

    public var buttonTheme: TaskbarTheme = .standard {
        didSet { applyButtonTheme() }
    }

    public var showsLabels: Bool = true {
        didSet { rebuildButtons() }
    }

    /// Icon diameter (in points) for every button this strip builds.
    public var iconSize: CGFloat = 32 {
        didSet { rebuildButtons() }
    }

    /// When true (the default), windows are grouped into one button per app.
    /// When false, every window gets its own button/title, so each window
    /// can be activated, minimized, or closed individually.
    public var groupByApp: Bool = true {
        didSet { rebuildButtons() }
    }

    /// Bundle identifiers already pinned to the taskbar, *only on the
    /// primary display* — `TaskbarViewController` passes an empty set here
    /// for secondary-display strips. Their groups are withheld from this
    /// strip entirely — a pinned app's button lives in `PinnedAppsStripView`
    /// instead (merged with the running app once it has windows), so showing
    /// it here too would duplicate it. That merge only ever happens on the
    /// primary display, though: a pinned app's window that's actually open on
    /// a secondary display still needs its own ordinary button there, since
    /// nothing on that screen represents it otherwise.
    public var pinnedBundleIdentifiers: Set<String> = [] {
        didSet { rebuildButtons() }
    }

    /// Every currently pinned bundle identifier, regardless of display —
    /// unlike `pinnedBundleIdentifiers`, always fully populated even on a
    /// secondary-display strip. Used only to hide the redundant "Pin to
    /// Taskbar" context-menu item for a group/window whose app is already
    /// pinned (which `pinnedBundleIdentifiers` being empty there would
    /// otherwise miss).
    public var allPinnedBundleIdentifiers: Set<String> = []

    /// Every currently favorited (Quick Launch) bundle identifier, regardless
    /// of display — same rationale as `allPinnedBundleIdentifiers`, just for
    /// hiding the redundant "Pin to Quick Launch" item instead.
    public var allQuickLaunchFavoriteBundleIdentifiers: Set<String> = []

    /// Whether this strip belongs to the primary (real-Dock-following)
    /// taskbar instance rather than a secondary-display one
    /// (`behavior.showOnAllDisplays`). A window only ever gets a button on
    /// the one taskbar for the display it's actually on (see
    /// `RunningWindow.hostScreen`) — this decides who claims a window whose
    /// screen can't be determined at all, so it always ends up shown
    /// *somewhere* rather than silently vanishing.
    public var isPrimaryDisplay: Bool = true {
        didSet { rebuildButtons() }
    }

    /// Requests pinning the given app to the taskbar, from a running
    /// window/group's right-click menu. The caller (`TaskbarViewController`)
    /// owns the actual pinned-apps list and is responsible for de-duplicating.
    public var onPin: ((PinnedAppEntry) -> Void)?

    /// Requests favoriting the given app to the Quick Launch menu, from a
    /// running window/group's right-click menu — same caller-owns-the-list
    /// contract as `onPin`, just for `quickLaunchFavorites` instead of
    /// `pinnedApps`.
    public var onFavorite: ((PinnedAppEntry) -> Void)?

    /// Fired every time `refresh()` re-enumerates windows, with the group
    /// list *unfiltered* by pinned status or by display — `TaskbarViewController`
    /// forwards this to `PinnedAppsStripView`, which only ever exists on the
    /// primary display and should merge with a pinned app's windows
    /// regardless of which screen they're actually on (mirroring how a
    /// single Dock icon controls an app's windows across every display).
    public var onGroupsUpdated: (([RunningAppGroup]) -> Void)?

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        applyOrientation()

        registerForWorkspaceNotifications()
        restartPolling()
        refresh()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func applyOrientation() {
        stackView.orientation = orientation
        stackView.alignment = orientation == .horizontal ? .centerY : .centerX

        NSLayoutConstraint.deactivate(orientationConstraints)
        orientationConstraints = orientation == .horizontal
            ? [
                stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
                stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
                stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            ]
            : [
                stackView.topAnchor.constraint(equalTo: topAnchor),
                stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
                stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            ]
        NSLayoutConstraint.activate(orientationConstraints)
    }

    deinit {
        pollTimer?.invalidate()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    private func registerForWorkspaceNotifications() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(refresh), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        center.addObserver(self, selector: #selector(refresh), name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        center.addObserver(self, selector: #selector(handleAppActivated(_:)), name: NSWorkspace.didActivateApplicationNotification, object: nil)
    }

    /// `didActivateApplicationNotification` also fires when DockSheath
    /// activates itself (e.g. via Settings/Onboarding/the Dock-health alert,
    /// which all call `NSApp.activate(ignoringOtherApps:)`) — that never
    /// means some other app's windows changed, so rebuilding here would be
    /// not just wasteful but destructive if it raced with an in-flight
    /// click's gesture recognizer on a `TaskbarButton` (see
    /// `rebuildButtons()`, which tears down and reconstructs every button).
    /// Only forward to `refresh()` for genuinely different apps activating.
    @objc private func handleAppActivated(_ notification: Notification) {
        guard let activatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              activatedApp.processIdentifier != NSRunningApplication.current.processIdentifier
        else { return }
        refresh()
    }

    private func restartPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: refreshIntervalSeconds, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    @objc public func refresh() {
        groups = service.enumerateGroups()
        onGroupsUpdated?(groups)
        rebuildButtons()
    }

    private func rebuildButtons() {
        let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        // Only the windows actually on this taskbar's own screen — a group
        // with windows spread across multiple displays gets a differently
        // (and correctly) sized button on each one.
        let onThisDisplay: [RunningAppGroup] = groups.compactMap { group in
            let windowsHere = group.windows.filter(belongsOnThisDisplay)
            guard !windowsHere.isEmpty else { return nil }
            var filtered = group
            filtered.windows = windowsHere
            return filtered
        }
        // Pinned apps get their button from `PinnedAppsStripView` instead —
        // once they have windows it merges with what would otherwise be this
        // exact group, so it must not also appear here.
        let visibleGroups = onThisDisplay.filter {
            guard let bundleIdentifier = $0.bundleIdentifier else { return true }
            return !pinnedBundleIdentifiers.contains(bundleIdentifier)
        }

        let newState: [RenderedButtonState]
        if groupByApp {
            newState = visibleGroups.map { group in
                RenderedButtonState(
                    isGrouped: true,
                    icon: group.icon,
                    title: group.taskbarDisplayLabel,
                    tooltip: group.taskbarTooltip,
                    isHighlighted: group.id == frontmostPID,
                    showsLabel: showsLabels,
                    iconSize: iconSize
                )
            }
        } else {
            newState = visibleGroups.flatMap { group in
                group.windows.map { window in
                    let title = window.title?.isEmpty == false ? window.title! : group.appName
                    return RenderedButtonState(
                        isGrouped: false,
                        icon: group.icon,
                        title: title,
                        tooltip: nil,
                        isHighlighted: group.id == frontmostPID,
                        showsLabel: showsLabels,
                        iconSize: iconSize
                    )
                }
            }
        }

        guard newState != lastRenderedState else { return }
        lastRenderedState = newState

        stackView.arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        if groupByApp {
            for group in visibleGroups {
                let button = TaskbarButton(icon: group.icon, title: group.taskbarDisplayLabel, iconSize: iconSize)
                button.toolTip = group.taskbarTooltip
                button.showsLabel = showsLabels
                button.applyTheme(buttonTheme)
                button.isHighlighted = group.id == frontmostPID
                button.onClick = { [weak self] in self?.handleClick(group: group) }
                button.onRightClick = { [weak self] in self?.showContextMenu(for: group, from: button) }
                button.onMiddleClick = { [weak self] in self?.launchNewInstance(bundleIdentifier: group.bundleIdentifier) }
                stackView.addArrangedSubview(button)
            }
        } else {
            for group in visibleGroups {
                for window in group.windows {
                    let title = window.title?.isEmpty == false ? window.title! : group.appName
                    let button = TaskbarButton(icon: group.icon, title: title, iconSize: iconSize)
                    button.showsLabel = showsLabels
                    button.applyTheme(buttonTheme)
                    button.isHighlighted = group.id == frontmostPID
                    button.onClick = { [weak self] in self?.handleClick(window: window) }
                    button.onRightClick = { [weak self] in self?.showWindowContextMenu(for: window, from: button) }
                    button.onMiddleClick = { [weak self] in self?.launchNewInstance(bundleIdentifier: window.ownerBundleIdentifier) }
                    stackView.addArrangedSubview(button)
                }
            }
        }
    }

    /// Whether `runningWindow` belongs on this particular taskbar instance —
    /// true if it's actually on the screen this strip's own window
    /// currently occupies, or if its screen can't be determined at all
    /// (either `RunningWindow.hostScreen` came back nil, or this view isn't
    /// installed in a window yet) and this happens to be the primary
    /// display's strip, which claims every otherwise-unclaimed window.
    private func belongsOnThisDisplay(_ runningWindow: RunningWindow) -> Bool {
        guard let hostScreen = runningWindow.hostScreen, let ownScreen = window?.screen else {
            return isPrimaryDisplay
        }
        return hostScreen.directDisplayID == ownScreen.directDisplayID
    }

    private func applyButtonTheme() {
        for case let button as TaskbarButton in stackView.arrangedSubviews {
            button.applyTheme(buttonTheme)
        }
    }

    private func handleClick(group: RunningAppGroup) {
        AccessibilityWindowController.activateOrMinimize(group, frontmostPID: NSWorkspace.shared.frontmostApplication?.processIdentifier)
        refresh()
    }

    private func showContextMenu(for group: RunningAppGroup, from view: NSView) {
        let menu = NSMenu()
        menu.addItem(withTitle: "Minimize", action: #selector(minimizeMenuAction(_:)), keyEquivalent: "")
            .representedObject = group
        menu.addItem(withTitle: "Close", action: #selector(closeMenuAction(_:)), keyEquivalent: "")
            .representedObject = group
        let showPinToTaskbar = !isPinned(bundleIdentifier: group.bundleIdentifier)
        let showPinToQuickLaunch = !isFavorited(bundleIdentifier: group.bundleIdentifier)
        if showPinToTaskbar || showPinToQuickLaunch {
            menu.addItem(.separator())
            if showPinToTaskbar {
                menu.addItem(withTitle: "Pin to Taskbar", action: #selector(pinGroupMenuAction(_:)), keyEquivalent: "")
                    .representedObject = group
            }
            if showPinToQuickLaunch {
                menu.addItem(withTitle: "Pin to Quick Launch", action: #selector(favoriteGroupMenuAction(_:)), keyEquivalent: "")
                    .representedObject = group
            }
        }
        for item in menu.items {
            item.target = self
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: view.bounds.height), in: view)
    }

    private func isPinned(bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return allPinnedBundleIdentifiers.contains(bundleIdentifier)
    }

    private func isFavorited(bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return allQuickLaunchFavoriteBundleIdentifiers.contains(bundleIdentifier)
    }

    @objc private func minimizeMenuAction(_ sender: NSMenuItem) {
        guard let group = sender.representedObject as? RunningAppGroup else { return }
        group.windows.forEach(AccessibilityWindowController.minimize)
        refresh()
    }

    @objc private func closeMenuAction(_ sender: NSMenuItem) {
        guard let group = sender.representedObject as? RunningAppGroup else { return }
        group.windows.forEach(AccessibilityWindowController.close)
        refresh()
    }

    @objc private func pinGroupMenuAction(_ sender: NSMenuItem) {
        guard let group = sender.representedObject as? RunningAppGroup else { return }
        pin(bundleIdentifier: group.bundleIdentifier)
    }

    @objc private func favoriteGroupMenuAction(_ sender: NSMenuItem) {
        guard let group = sender.representedObject as? RunningAppGroup else { return }
        favorite(bundleIdentifier: group.bundleIdentifier)
    }

    // MARK: - Ungrouped (per-window) actions

    private func handleClick(window: RunningWindow) {
        let isFrontmost = window.pid == NSWorkspace.shared.frontmostApplication?.processIdentifier

        if isFrontmost && !window.isMinimized {
            AccessibilityWindowController.minimize(window)
        } else {
            AccessibilityWindowController.activate(window)
        }
        refresh()
    }

    private func showWindowContextMenu(for window: RunningWindow, from view: NSView) {
        let menu = NSMenu()
        menu.addItem(withTitle: "Minimize", action: #selector(minimizeWindowMenuAction(_:)), keyEquivalent: "")
            .representedObject = window
        menu.addItem(withTitle: "Close", action: #selector(closeWindowMenuAction(_:)), keyEquivalent: "")
            .representedObject = window
        let showPinToTaskbar = !isPinned(bundleIdentifier: window.ownerBundleIdentifier)
        let showPinToQuickLaunch = !isFavorited(bundleIdentifier: window.ownerBundleIdentifier)
        if showPinToTaskbar || showPinToQuickLaunch {
            menu.addItem(.separator())
            if showPinToTaskbar {
                menu.addItem(withTitle: "Pin to Taskbar", action: #selector(pinWindowMenuAction(_:)), keyEquivalent: "")
                    .representedObject = window
            }
            if showPinToQuickLaunch {
                menu.addItem(withTitle: "Pin to Quick Launch", action: #selector(favoriteWindowMenuAction(_:)), keyEquivalent: "")
                    .representedObject = window
            }
        }
        for item in menu.items {
            item.target = self
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: view.bounds.height), in: view)
    }

    @objc private func minimizeWindowMenuAction(_ sender: NSMenuItem) {
        guard let window = sender.representedObject as? RunningWindow else { return }
        AccessibilityWindowController.minimize(window)
        refresh()
    }

    @objc private func closeWindowMenuAction(_ sender: NSMenuItem) {
        guard let window = sender.representedObject as? RunningWindow else { return }
        AccessibilityWindowController.close(window)
        refresh()
    }

    @objc private func pinWindowMenuAction(_ sender: NSMenuItem) {
        guard let window = sender.representedObject as? RunningWindow else { return }
        pin(bundleIdentifier: window.ownerBundleIdentifier)
    }

    @objc private func favoriteWindowMenuAction(_ sender: NSMenuItem) {
        guard let window = sender.representedObject as? RunningWindow else { return }
        favorite(bundleIdentifier: window.ownerBundleIdentifier)
    }

    /// Resolves a bundle identifier (all a running window/group carries) to
    /// an installed app's on-disk path so a `PinnedAppEntry` (which needs a
    /// `bundlePath`) can be constructed from it.
    private func pin(bundleIdentifier: String?) {
        guard let bundleIdentifier,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else { return }
        onPin?(PinnedAppEntry(bundlePath: url.path, bundleIdentifier: bundleIdentifier))
    }

    private func favorite(bundleIdentifier: String?) {
        guard let bundleIdentifier,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else { return }
        onFavorite?(PinnedAppEntry(bundlePath: url.path, bundleIdentifier: bundleIdentifier))
    }

    /// Middle-click on any running-window button — launches another copy of
    /// the app rather than activating the window(s) already open, which is
    /// what a plain click does.
    private func launchNewInstance(bundleIdentifier: String?) {
        guard let bundleIdentifier,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }
}
