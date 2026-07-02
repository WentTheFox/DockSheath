import AppKit
import JSON5Config
import DockOverlayKit

/// Composes the taskbar's layout: Start button → pinned-apps strip →
/// separator → running-windows strip (grouped by owning app). Lays out
/// horizontally when the Dock (and therefore the taskbar) is at the bottom
/// of the screen, or vertically when it's on the left or right — following
/// `updateLayout(for:)` calls driven by `OverlayWindowController`.
public final class TaskbarViewController: NSViewController {
    private let startButton = TaskbarButton(
        icon: NSImage(systemSymbolName: "square.grid.2x2.fill", accessibilityDescription: "Quick Launch"),
        title: "Quick Launch"
    )
    private let pinnedStrip = PinnedAppsStripView(frame: .zero)
    private let runningStrip = RunningWindowsStripView(frame: .zero)
    private let separator = NSBox()
    private var separatorWidthConstraint: NSLayoutConstraint!
    private var separatorHeightConstraint: NSLayoutConstraint!
    private var stack: NSStackView!
    private var stackConstraints: [NSLayoutConstraint] = []
    private var quickLaunchController: QuickLaunchWindowController?
    private var currentEdge: DockEdge = .bottom

    public var pinnedApps: [PinnedAppEntry] = [] {
        didSet { pinnedStrip.pinnedApps = pinnedApps }
    }
    public var onPinnedAppsChanged: (([PinnedAppEntry]) -> Void)?

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

        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        separatorWidthConstraint = separator.widthAnchor.constraint(equalToConstant: 1)
        separatorHeightConstraint = separator.heightAnchor.constraint(equalToConstant: 24)
        NSLayoutConstraint.activate([separatorWidthConstraint, separatorHeightConstraint])

        stack = NSStackView(views: [startButton, pinnedStrip, separator, runningStrip])
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        applyOrientation()

        startButton.onClick = { [weak self] in self?.toggleQuickLaunch() }
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
    }

    private func toggleQuickLaunch() {
        if let controller = quickLaunchController, controller.isVisible {
            controller.hide()
            return
        }

        let controller = QuickLaunchWindowController(
            onLaunch: { [weak self] app in self?.launch(app) },
            onPin: { [weak self] app in self?.pin(app) }
        )
        quickLaunchController = controller

        guard let window = view.window else { return }
        let buttonFrameInWindow = startButton.convert(startButton.bounds, to: nil)
        let screenFrame = window.convertToScreen(buttonFrameInWindow)

        let anchorPoint: NSPoint
        switch currentEdge {
        case .bottom:
            anchorPoint = NSPoint(x: screenFrame.midX, y: screenFrame.maxY)
        case .left:
            anchorPoint = NSPoint(x: screenFrame.maxX, y: screenFrame.midY)
        case .right:
            anchorPoint = NSPoint(x: screenFrame.minX, y: screenFrame.midY)
        }
        controller.show(near: anchorPoint, dockEdge: currentEdge)
    }

    private func launch(_ app: InstalledApp) {
        NSWorkspace.shared.openApplication(
            at: URL(fileURLWithPath: app.bundlePath),
            configuration: NSWorkspace.OpenConfiguration()
        )
        quickLaunchController?.hide()
    }

    private func pin(_ app: InstalledApp) {
        guard !pinnedApps.contains(where: { $0.bundlePath == app.bundlePath }) else { return }
        pinnedApps.append(PinnedAppEntry(bundlePath: app.bundlePath, bundleIdentifier: app.bundleIdentifier))
        onPinnedAppsChanged?(pinnedApps)
    }
}
