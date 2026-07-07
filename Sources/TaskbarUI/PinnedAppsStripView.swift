import AppKit
import AXWindowKit
import JSON5Config

/// The taskbar strip of pinned "quick launch" apps, backed by
/// `TaskbarConfig.pinnedApps`. Occupies a fixed zone ahead of the
/// running-windows strip, matching uBar's model of two distinct areas — but
/// a pinned app's own button merges with its running-window button rather
/// than showing both: once `runningGroups` has a match for a pinned entry,
/// that entry's button switches from an icon-only launcher to the same
/// activate/minimize button `RunningWindowsStripView` would otherwise render
/// for it (which withholds that group from its own strip once it sees the
/// same bundle identifier in `pinnedApps`, via
/// `RunningWindowsStripView.pinnedBundleIdentifiers`). Because the button
/// stays in this strip either way, a pinned app's position never moves when
/// its windows open/close/multiply — only the running-windows strip's own,
/// unpinned groups reflow around it.
public final class PinnedAppsStripView: NSView {
    /// A memoized representation of the last set of buttons actually built —
    /// see `RunningWindowsStripView.RenderedButtonState`, which this mirrors.
    /// `runningGroups` gets reassigned every ~1.5s poll tick regardless of
    /// whether anything actually changed (`TaskbarViewController` forwards
    /// `RunningWindowsStripView.onGroupsUpdated` unconditionally), so without
    /// this gate a pinned app's button would flicker in lockstep even though
    /// pinned apps themselves rarely change.
    private struct RenderedButtonState: Equatable {
        /// True once a pinned entry has a matching running group, at which
        /// point its button switches from an icon-only launcher to an
        /// activate/minimize button — kept distinct so that transition
        /// always forces a real rebuild even in the (rare) case an app's
        /// resolved launcher icon/name happens to match its running state.
        let isMerged: Bool
        let icon: NSImage?
        let title: String
        let tooltip: String?
        let isHighlighted: Bool
        let showsLabel: Bool
        /// Compared for the same reason as `RunningWindowsStripView
        /// .RenderedButtonState.iconSize` — baked into the button at
        /// construction time, so it must be part of the diff or an
        /// icon-size-only change would be treated as "nothing changed".
        let iconSize: CGFloat

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.isMerged == rhs.isMerged
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
    private var lastRenderedState: [RenderedButtonState] = []
    /// Memoizes `NSWorkspace.icon(forFile:)` results by bundle path so a
    /// not-yet-running pinned app's icon stays the same `NSImage` instance
    /// across rebuilds — `NSWorkspace.icon(forFile:)`, unlike
    /// `NSRunningApplication.icon`, isn't known to reliably return the same
    /// instance for repeat calls, which would otherwise make `RenderedButtonState`
    /// see a "changed" icon on every single rebuild and defeat the memoization
    /// gate above for this specific case.
    private var launcherIconCache: [String: NSImage] = [:]
    public var pinnedApps: [PinnedAppEntry] = [] {
        didSet { rebuildButtons() }
    }

    /// The taskbar's full set of currently running app groups, supplied by
    /// `TaskbarViewController` from `RunningWindowsStripView.onGroupsUpdated`.
    public var runningGroups: [RunningAppGroup] = [] {
        didSet { rebuildButtons() }
    }

    public var onUnpin: ((PinnedAppEntry) -> Void)?

    /// Fired after this view performs a window action (minimize/close/click)
    /// on a merged pinned+running button, so `TaskbarViewController` can ask
    /// `RunningWindowsStripView` to re-enumerate immediately instead of
    /// waiting for its next poll.
    public var onRequestRefresh: (() -> Void)?

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

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        applyOrientation()
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

    private func rebuildButtons() {
        let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier

        let newState: [RenderedButtonState] = pinnedApps.map { entry in
            let group = runningGroups.first { $0.bundleIdentifier != nil && $0.bundleIdentifier == entry.bundleIdentifier }
            if let group {
                return RenderedButtonState(
                    isMerged: true,
                    icon: group.icon,
                    title: group.taskbarDisplayLabel,
                    tooltip: group.taskbarTooltip,
                    isHighlighted: group.id == frontmostPID,
                    showsLabel: showsLabels,
                    iconSize: iconSize
                )
            }
            let icon = launcherIcon(forBundlePath: entry.bundlePath)
            let name = (entry.bundlePath as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
            return RenderedButtonState(
                isMerged: false,
                icon: icon,
                title: name,
                tooltip: nil,
                isHighlighted: false,
                showsLabel: false,
                iconSize: iconSize
            )
        }

        guard newState != lastRenderedState else { return }
        lastRenderedState = newState

        stackView.arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        for entry in pinnedApps {
            let group = runningGroups.first { $0.bundleIdentifier != nil && $0.bundleIdentifier == entry.bundleIdentifier }
            let button: TaskbarButton

            if let group {
                button = TaskbarButton(icon: group.icon, title: group.taskbarDisplayLabel, iconSize: iconSize)
                button.toolTip = group.taskbarTooltip
                button.showsLabel = showsLabels
                button.isHighlighted = group.id == frontmostPID
                button.onClick = { [weak self] in self?.handleClick(group: group) }
                button.onRightClick = { [weak self] in self?.showContextMenu(for: entry, group: group, from: button) }
                button.onMiddleClick = { [weak self] in self?.launch(entry, newInstance: true) }
            } else {
                let icon = launcherIcon(forBundlePath: entry.bundlePath)
                let name = (entry.bundlePath as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
                button = TaskbarButton(icon: icon, title: name, iconSize: iconSize)
                // Hidden regardless of `showsLabels` — a pinned app that
                // hasn't been opened yet has no window title to show, and an
                // app-name label would just duplicate the icon's tooltip.
                button.showsLabel = false
                button.onClick = { [weak self] in self?.launch(entry) }
                button.onRightClick = { [weak self] in self?.showContextMenu(for: entry, group: nil, from: button) }
                button.onMiddleClick = { [weak self] in self?.launch(entry, newInstance: true) }
            }

            button.applyTheme(buttonTheme)
            stackView.addArrangedSubview(button)
        }
    }

    /// Memoized `NSWorkspace.icon(forFile:)` lookup — see `launcherIconCache`.
    private func launcherIcon(forBundlePath path: String) -> NSImage {
        if let cached = launcherIconCache[path] {
            return cached
        }
        let icon = NSWorkspace.shared.icon(forFile: path)
        launcherIconCache[path] = icon
        return icon
    }

    private func applyButtonTheme() {
        for case let button as TaskbarButton in stackView.arrangedSubviews {
            button.applyTheme(buttonTheme)
        }
    }

    /// `newInstance` is true for a middle-click on an already-running (or
    /// pinned-only) app's button — otherwise `NSWorkspace` would just
    /// activate the existing instance instead of launching another one.
    private func launch(_ entry: PinnedAppEntry, newInstance: Bool = false) {
        let url = URL(fileURLWithPath: entry.bundlePath)
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = newInstance
        NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }

    private func handleClick(group: RunningAppGroup) {
        AccessibilityWindowController.activateOrMinimize(group, frontmostPID: NSWorkspace.shared.frontmostApplication?.processIdentifier)
        onRequestRefresh?()
    }

    /// `group` is non-nil once the pinned app has open windows, adding
    /// Minimize/Close ahead of the always-present Unpin item.
    private func showContextMenu(for entry: PinnedAppEntry, group: RunningAppGroup?, from view: NSView) {
        let menu = NSMenu()

        if let group {
            menu.addItem(withTitle: "Minimize", action: #selector(minimizeMenuAction(_:)), keyEquivalent: "")
                .representedObject = group
            menu.addItem(withTitle: "Close", action: #selector(closeMenuAction(_:)), keyEquivalent: "")
                .representedObject = group
            menu.addItem(.separator())
        }

        menu.addItem(withTitle: "Unpin from Taskbar", action: #selector(unpinMenuAction(_:)), keyEquivalent: "")
            .representedObject = entry

        for item in menu.items {
            item.target = self
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: view.bounds.height), in: view)
    }

    @objc private func minimizeMenuAction(_ sender: NSMenuItem) {
        guard let group = sender.representedObject as? RunningAppGroup else { return }
        group.windows.forEach(AccessibilityWindowController.minimize)
        onRequestRefresh?()
    }

    @objc private func closeMenuAction(_ sender: NSMenuItem) {
        guard let group = sender.representedObject as? RunningAppGroup else { return }
        group.windows.forEach(AccessibilityWindowController.close)
        onRequestRefresh?()
    }

    @objc private func unpinMenuAction(_ sender: NSMenuItem) {
        guard let entry = sender.representedObject as? PinnedAppEntry else { return }
        onUnpin?(entry)
    }
}
