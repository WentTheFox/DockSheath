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
    private let stackView = NSStackView()
    private var orientationConstraints: [NSLayoutConstraint] = []
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
        stackView.arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier

        for entry in pinnedApps {
            let group = runningGroups.first { $0.bundleIdentifier != nil && $0.bundleIdentifier == entry.bundleIdentifier }
            let button: TaskbarButton

            if let group {
                button = TaskbarButton(icon: group.icon, title: group.taskbarDisplayLabel)
                button.toolTip = group.taskbarTooltip
                button.showsLabel = showsLabels
                button.isHighlighted = group.id == frontmostPID
                button.onClick = { [weak self] in self?.handleClick(group: group) }
                button.onRightClick = { [weak self] in self?.showContextMenu(for: entry, group: group, from: button) }
            } else {
                let icon = NSWorkspace.shared.icon(forFile: entry.bundlePath)
                let name = (entry.bundlePath as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
                button = TaskbarButton(icon: icon, title: name)
                // Hidden regardless of `showsLabels` — a pinned app that
                // hasn't been opened yet has no window title to show, and an
                // app-name label would just duplicate the icon's tooltip.
                button.showsLabel = false
                button.onClick = { [weak self] in self?.launch(entry) }
                button.onRightClick = { [weak self] in self?.showContextMenu(for: entry, group: nil, from: button) }
            }

            button.applyTheme(buttonTheme)
            stackView.addArrangedSubview(button)
        }
    }

    private func applyButtonTheme() {
        for case let button as TaskbarButton in stackView.arrangedSubviews {
            button.applyTheme(buttonTheme)
        }
    }

    private func launch(_ entry: PinnedAppEntry) {
        let url = URL(fileURLWithPath: entry.bundlePath)
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
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
