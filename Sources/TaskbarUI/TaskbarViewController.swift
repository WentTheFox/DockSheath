import AppKit
import JSON5Config
import DockOverlayKit

/// Composes the taskbar's layout: Start button → pinned-apps strip →
/// separator → running-windows strip (grouped by owning app, unless
/// `groupWindowsByApp` is false). Lays out horizontally when the Dock (and
/// therefore the taskbar) is at the bottom of the screen, or vertically when
/// it's on the left or right — following `updateLayout(for:)` calls driven
/// by `OverlayWindowController`.
public final class TaskbarViewController: NSViewController {
    private let startButton = TaskbarButton(
        icon: NSImage(systemSymbolName: "square.grid.2x2.fill", accessibilityDescription: "Quick Launch"),
        title: "Quick Launch"
    )
    private let pinnedStrip = PinnedAppsStripView(frame: .zero)
    private let runningStrip = RunningWindowsStripView(frame: .zero)
    private let separator = NSBox()
    private let backgroundVisualEffect = NSVisualEffectView()
    private let displayNumberLabel = NSTextField(labelWithString: "")
    private let clockLabel = NSTextField(labelWithString: "")
    private let clockDateFormatter = DateFormatter()
    private var clockTimer: Timer?
    private var separatorWidthConstraint: NSLayoutConstraint!
    private var separatorHeightConstraint: NSLayoutConstraint!
    private var stack: NSStackView!
    private var indicatorStack: NSStackView!
    private var stackConstraints: [NSLayoutConstraint] = []
    private var indicatorConstraints: [NSLayoutConstraint] = []
    private var currentEdge: DockEdge = .bottom

    public var pinnedApps: [PinnedAppEntry] = [] {
        didSet { applyPinnedAppsAndDisplayRole() }
    }

    /// Apps pinned to the top of the Quick Launch menu's app list — separate
    /// from `pinnedApps` (the taskbar strip). Read by
    /// `quickLaunchMenuController` each time the menu opens.
    public var quickLaunchFavorites: [PinnedAppEntry] = [] {
        didSet { applyPinnedAppsAndDisplayRole() }
    }
    public var onQuickLaunchFavoritesChanged: (([PinnedAppEntry]) -> Void)?
    private let quickLaunchMenuController = QuickLaunchMenuController()

    /// Whether this is the primary (real-Dock-following) taskbar instance,
    /// as opposed to one of the optional secondary-display ones
    /// (`behavior.showOnAllDisplays`). Pinned apps only ever show here — a
    /// launcher repeated identically on every screen would just be visual
    /// noise, since launching/activating an app works the same from any one
    /// of them — and it's also the fallback claimant for a running-window
    /// button whose screen can't be determined (see
    /// `RunningWindowsStripView.isPrimaryDisplay`).
    public var isPrimaryDisplay: Bool = true {
        didSet { applyPinnedAppsAndDisplayRole() }
    }

    public var onPinnedAppsChanged: (([PinnedAppEntry]) -> Void)?
    /// Opens Settings to the Pinned Apps tab, from the Quick Launch menu's
    /// "Open Settings…" item.
    public var onManagePinnedApps: (() -> Void)?

    /// The resolved appearance/color theme applied to the taskbar's own
    /// background/border and passed down to every button. Defaults to
    /// `.standard`, which follows the system light/dark appearance and
    /// accent color with no persistent button fill — matching the look
    /// before per-element color overrides existed.
    public var theme: TaskbarTheme = .standard {
        didSet { applyTheme() }
    }

    /// Whether every taskbar button shows a text label below its icon — for
    /// running-window buttons, that label is the window's title (see
    /// `RunningWindowsStripView.displayLabel(for:)`).
    public var showAppLabels: Bool = true {
        didSet { applyShowLabels() }
    }

    /// Whether running windows are grouped one-button-per-app (the default)
    /// or given one button per individual window.
    public var groupWindowsByApp: Bool = true {
        didSet { applyGroupWindowsByApp() }
    }

    /// Icon diameter (in points) for pinned and running-window buttons. The
    /// Start button's icon size is fixed regardless of this value, since
    /// it's a `let`-constructed stored property rather than one rebuilt on
    /// every refresh like the strips' buttons are.
    public var iconSize: CGFloat = 32 {
        didSet { applyIconSize() }
    }

    /// How often `runningStrip` re-enumerates windows as a fallback poll,
    /// in seconds — see `RunningWindowsStripView.refreshIntervalSeconds`.
    public var refreshIntervalSeconds: TimeInterval {
        get { runningStrip.refreshIntervalSeconds }
        set { runningStrip.refreshIntervalSeconds = newValue }
    }

    /// 1-based, following `NSScreen.screens` order — only meaningful when
    /// `showDisplayNumber` is on.
    public var displayNumber: Int = 1 {
        didSet { updateDisplayNumberIndicator() }
    }
    /// Shows a small badge with `displayNumber` at the taskbar's trailing
    /// edge.
    public var showDisplayNumber: Bool = false {
        didSet { updateDisplayNumberIndicator() }
    }
    /// Whether/how to show a taskbar clock, also at the trailing edge (after
    /// the display-number badge, if both are shown).
    public var clockConfig: ClockConfig = ClockConfig() {
        didSet { applyClockConfig() }
    }

    public override func loadView() {
        view = NSView()
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setUpLayout()

        pinnedStrip.onUnpin = { [weak self] entry in
            guard let self else { return }
            pinnedApps.removeAll { $0.id == entry.id }
            onPinnedAppsChanged?(pinnedApps)
        }

        runningStrip.onPin = { [weak self] entry in
            guard let self else { return }
            guard !pinnedApps.contains(where: { $0.bundlePath == entry.bundlePath }) else { return }
            pinnedApps.append(entry)
            onPinnedAppsChanged?(pinnedApps)
        }

        runningStrip.onFavorite = { [weak self] entry in
            guard let self else { return }
            guard !quickLaunchFavorites.contains(where: { $0.bundlePath == entry.bundlePath }) else { return }
            quickLaunchFavorites.append(entry)
            onQuickLaunchFavoritesChanged?(quickLaunchFavorites)
        }

        runningStrip.onGroupsUpdated = { [weak self] groups in
            self?.pinnedStrip.runningGroups = groups
        }
        pinnedStrip.onRequestRefresh = { [weak self] in
            self?.runningStrip.refresh()
        }
        // `runningStrip` already ran its own initial `refresh()` during
        // construction, before the callback above existed to catch it — redo
        // it now so already-running pinned apps merge immediately instead of
        // only after the first poll tick.
        runningStrip.refresh()
    }

    deinit {
        clockTimer?.invalidate()
    }

    /// Re-lays out the taskbar for the Dock's current edge. Safe to call
    /// before the view has loaded (the edge is just recorded for when
    /// `setUpLayout()` runs) and safe to call repeatedly — it's a no-op if
    /// the edge hasn't actually changed.
    public func updateLayout(for edge: DockEdge) {
        let didChange = currentEdge != edge
        currentEdge = edge
        guard didChange, stack != nil else { return }
        applyOrientation()
    }

    private func setUpLayout() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor

        // Default background: a system vibrancy material, which automatically
        // tracks light/dark appearance with zero configuration. Swapped for a
        // solid custom fill in applyTheme() when the user sets an explicit
        // taskbarColors.background override.
        backgroundVisualEffect.material = .menu
        backgroundVisualEffect.blendingMode = .behindWindow
        backgroundVisualEffect.state = .active
        backgroundVisualEffect.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundVisualEffect)
        NSLayoutConstraint.activate([
            backgroundVisualEffect.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundVisualEffect.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundVisualEffect.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundVisualEffect.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        separatorWidthConstraint = separator.widthAnchor.constraint(equalToConstant: 1)
        separatorHeightConstraint = separator.heightAnchor.constraint(equalToConstant: 24)
        NSLayoutConstraint.activate([separatorWidthConstraint, separatorHeightConstraint])

        stack = NSStackView(views: [startButton, pinnedStrip, separator, runningStrip])
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        displayNumberLabel.alignment = .center
        displayNumberLabel.isHidden = true

        clockLabel.isHidden = true

        indicatorStack = NSStackView(views: [displayNumberLabel, clockLabel])
        indicatorStack.spacing = 6
        indicatorStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(indicatorStack)

        applyOrientation()
        applyTheme()
        applyShowLabels()
        applyGroupWindowsByApp()
        applyIconSize()
        updateDisplayNumberIndicator()
        applyClockConfig()

        startButton.onClick = { [weak self] in self?.showQuickLaunchMenu() }
    }

    /// Applies `theme` to the taskbar's own background/border and to every
    /// button (Start, pinned, running). Safe to call before `viewDidLoad()`
    /// runs — it's a no-op until `setUpLayout()` has created
    /// `backgroundVisualEffect`.
    private func applyTheme() {
        guard isViewLoaded else { return }

        view.appearance = theme.appearance

        if let background = theme.taskbarBackground {
            backgroundVisualEffect.isHidden = true
            view.layer?.backgroundColor = background.cgColor
        } else {
            backgroundVisualEffect.isHidden = false
            view.layer?.backgroundColor = NSColor.clear.cgColor
        }

        view.layer?.borderColor = theme.taskbarBorder?.cgColor
        view.layer?.borderWidth = theme.taskbarBorder != nil ? 1 : 0

        startButton.applyTheme(theme)
        pinnedStrip.buttonTheme = theme
        runningStrip.buttonTheme = theme

        let indicatorTextColor = theme.buttonText ?? .labelColor
        displayNumberLabel.textColor = indicatorTextColor
        clockLabel.textColor = indicatorTextColor
        displayNumberLabel.font = theme.displayNumberFont
        clockLabel.font = theme.clockFont
    }

    /// Safe to call before `viewDidLoad()` runs — `pinnedStrip`/`runningStrip`
    /// are created eagerly as stored properties, not lazily in
    /// `setUpLayout()`.
    private func applyPinnedAppsAndDisplayRole() {
        let effectivePinnedApps = isPrimaryDisplay ? pinnedApps : []
        pinnedStrip.isHidden = !isPrimaryDisplay
        pinnedStrip.pinnedApps = effectivePinnedApps
        runningStrip.pinnedBundleIdentifiers = Set(effectivePinnedApps.compactMap(\.bundleIdentifier))
        runningStrip.allPinnedBundleIdentifiers = Set(pinnedApps.compactMap(\.bundleIdentifier))
        runningStrip.allQuickLaunchFavoriteBundleIdentifiers = Set(quickLaunchFavorites.compactMap(\.bundleIdentifier))
        runningStrip.isPrimaryDisplay = isPrimaryDisplay
    }

    /// Safe to call before `viewDidLoad()` runs, same as `applyTheme()`.
    private func applyShowLabels() {
        guard isViewLoaded else { return }

        pinnedStrip.showsLabels = showAppLabels
        runningStrip.showsLabels = showAppLabels
    }

    /// Safe to call before `viewDidLoad()` runs, same as `applyTheme()`.
    private func applyGroupWindowsByApp() {
        guard isViewLoaded else { return }
        runningStrip.groupByApp = groupWindowsByApp
    }

    /// Safe to call before `viewDidLoad()` runs, same as `applyTheme()`.
    private func applyIconSize() {
        guard isViewLoaded else { return }
        pinnedStrip.iconSize = iconSize
        runningStrip.iconSize = iconSize
    }

    private func updateDisplayNumberIndicator() {
        displayNumberLabel.isHidden = !showDisplayNumber
        displayNumberLabel.stringValue = "\(displayNumber)"
    }

    private func applyClockConfig() {
        clockLabel.isHidden = !clockConfig.enabled
        clockDateFormatter.dateFormat = clockConfig.format

        clockTimer?.invalidate()
        clockTimer = nil
        guard clockConfig.enabled else { return }

        updateClockLabel()
        clockTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateClockLabel()
        }
    }

    private func updateClockLabel() {
        clockLabel.stringValue = clockDateFormatter.string(from: Date())
    }

    private func applyOrientation() {
        let isHorizontal = currentEdge == .bottom
        let orientation: NSUserInterfaceLayoutOrientation = isHorizontal ? .horizontal : .vertical

        stack.orientation = orientation
        stack.alignment = isHorizontal ? .centerY : .centerX
        pinnedStrip.orientation = orientation
        runningStrip.orientation = orientation
        separatorWidthConstraint.constant = isHorizontal ? 1 : 24
        separatorHeightConstraint.constant = isHorizontal ? 24 : 1

        NSLayoutConstraint.deactivate(stackConstraints)
        stackConstraints = isHorizontal
            ? [
                stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
                stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -8),
                stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            ]
            : [
                stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
                stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -8),
                stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            ]
        NSLayoutConstraint.activate(stackConstraints)

        indicatorStack.orientation = orientation
        indicatorStack.alignment = isHorizontal ? .centerY : .centerX

        // Pinned to the taskbar's trailing (bottom, when vertical) edge
        // independent of `stack`'s own width, so it stays put at a fixed
        // corner rather than drifting with however many buttons are
        // currently showing. The inequality against `stack`'s far edge keeps
        // the two from visually overlapping if the running-windows strip
        // grows wide/tall enough to otherwise reach it.
        NSLayoutConstraint.deactivate(indicatorConstraints)
        indicatorConstraints = isHorizontal
            ? [
                indicatorStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
                indicatorStack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                indicatorStack.leadingAnchor.constraint(greaterThanOrEqualTo: stack.trailingAnchor, constant: 8),
            ]
            : [
                indicatorStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),
                indicatorStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                indicatorStack.topAnchor.constraint(greaterThanOrEqualTo: stack.bottomAnchor, constant: 8),
            ]
        NSLayoutConstraint.activate(indicatorConstraints)
    }

    /// The Start button's menu: `quickLaunchFavorites`, plus Settings/Quit/
    /// system power actions at the bottom — see `QuickLaunchMenuController`
    /// for the actual menu construction. A plain `NSMenu` gets outside-click,
    /// other-taskbar-button, and lost-focus dismissal for free, with no
    /// manual anchor-point/edge math needed here.
    private func showQuickLaunchMenu() {
        quickLaunchMenuController.favorites = quickLaunchFavorites
        quickLaunchMenuController.onManagePinnedApps = { [weak self] in self?.onManagePinnedApps?() }
        quickLaunchMenuController.show(from: startButton)
    }
}
