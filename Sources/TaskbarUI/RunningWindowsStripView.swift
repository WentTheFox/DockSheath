import AppKit
import AXWindowKit

/// The taskbar strip listing running application windows, grouped by owning
/// app. Refreshes on app launch/terminate/activate notifications plus a
/// coarse fallback poll for same-app window open/close (a fully
/// AXObserver-driven live refresh is a post-MVP improvement).
public final class RunningWindowsStripView: NSView {
    private let stackView = NSStackView()
    private var orientationConstraints: [NSLayoutConstraint] = []
    private let service = WindowEnumerationService()
    private var groups: [RunningAppGroup] = []
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
        center.addObserver(self, selector: #selector(refresh), name: NSWorkspace.didActivateApplicationNotification, object: nil)
    }

    private func restartPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: refreshIntervalSeconds, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    @objc public func refresh() {
        groups = service.enumerateGroups()
        rebuildButtons()
    }

    private func rebuildButtons() {
        stackView.arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier

        for group in groups {
            let button = TaskbarButton(icon: group.icon, title: displayLabel(for: group))
            button.toolTip = tooltipText(for: group)
            button.showsLabel = showsLabels
            button.applyTheme(buttonTheme)
            button.isHighlighted = group.id == frontmostPID
            button.onClick = { [weak self] in self?.handleClick(group: group) }
            button.onRightClick = { [weak self] in self?.showContextMenu(for: group, from: button) }
            stackView.addArrangedSubview(button)
        }
    }

    /// A single window's title when there's only one, or "AppName (N)" when
    /// the app has multiple windows grouped under this button — the
    /// individual titles are still available via `tooltipText(for:)`.
    private func displayLabel(for group: RunningAppGroup) -> String {
        if group.windows.count == 1, let title = group.windows[0].title, !title.isEmpty {
            return title
        }
        if group.windows.count > 1 {
            return "\(group.appName) (\(group.windows.count))"
        }
        return group.appName
    }

    private func tooltipText(for group: RunningAppGroup) -> String {
        guard group.windows.count > 1 else { return displayLabel(for: group) }
        return group.windows
            .map { $0.title?.isEmpty == false ? $0.title! : group.appName }
            .joined(separator: "\n")
    }

    private func applyButtonTheme() {
        for case let button as TaskbarButton in stackView.arrangedSubviews {
            button.applyTheme(buttonTheme)
        }
    }

    private func handleClick(group: RunningAppGroup) {
        guard let firstWindow = group.windows.first else { return }
        let isFrontmost = group.id == NSWorkspace.shared.frontmostApplication?.processIdentifier
        let anyMinimized = group.windows.contains { $0.isMinimized }

        if isFrontmost && !anyMinimized {
            group.windows.forEach(AccessibilityWindowController.minimize)
        } else {
            AccessibilityWindowController.activate(firstWindow)
        }
        refresh()
    }

    private func showContextMenu(for group: RunningAppGroup, from view: NSView) {
        let menu = NSMenu()
        menu.addItem(withTitle: "Minimize", action: #selector(minimizeMenuAction(_:)), keyEquivalent: "")
            .representedObject = group
        menu.addItem(withTitle: "Close", action: #selector(closeMenuAction(_:)), keyEquivalent: "")
            .representedObject = group
        for item in menu.items {
            item.target = self
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: view.bounds.height), in: view)
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
}
