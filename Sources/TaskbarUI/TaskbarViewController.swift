import AppKit
import JSON5Config

/// Composes the taskbar's horizontal layout: Start button → pinned-apps
/// strip → separator → running-windows strip (grouped by owning app).
public final class TaskbarViewController: NSViewController {
    private let startButton = TaskbarButton(
        icon: NSImage(systemSymbolName: "square.grid.2x2.fill", accessibilityDescription: "Quick Launch"),
        title: "Quick Launch"
    )
    private let pinnedStrip = PinnedAppsStripView(frame: .zero)
    private let runningStrip = RunningWindowsStripView(frame: .zero)
    private var quickLaunchController: QuickLaunchWindowController?

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

    private func setUpLayout() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor

        let stack = NSStackView(views: [startButton, pinnedStrip, separatorView(), runningStrip])
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -8),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        startButton.onClick = { [weak self] in self?.toggleQuickLaunch() }
    }

    private func separatorView() -> NSView {
        let box = NSBox()
        box.boxType = .separator
        box.translatesAutoresizingMaskIntoConstraints = false
        box.widthAnchor.constraint(equalToConstant: 1).isActive = true
        box.heightAnchor.constraint(equalToConstant: 24).isActive = true
        return box
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
        controller.show(anchoredAbove: NSPoint(x: screenFrame.midX, y: screenFrame.maxY))
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
