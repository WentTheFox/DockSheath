import AppKit

/// Owns the DockSheath overlay window's lifecycle: keeps it sized/positioned
/// to match the Dock's reserved space, reacts to screen changes, exposes a
/// show/hide toggle independent of the space-reservation logic, and reports
/// Dock health-check diagnoses so the UI can warn the user.
public final class OverlayWindowController {
    public let window: OverlayWindow
    public var heightOverride: CGFloat?
    public var onHealthChanged: ((DockHealthCheck.Diagnosis) -> Void)?

    private var lastDiagnosis: DockHealthCheck.Diagnosis?

    public init(contentViewController: NSViewController, screen: NSScreen? = nil) {
        let targetScreen = screen ?? NSScreen.main ?? NSScreen.screens[0]
        window = OverlayWindow(screen: targetScreen)
        window.contentViewController = contentViewController

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    public func start() {
        refreshGeometry()
        window.orderFrontRegardless()
    }

    public var isVisible: Bool { window.isVisible }

    public func show() {
        refreshGeometry()
        window.orderFrontRegardless()
    }

    public func hide() {
        window.orderOut(nil)
    }

    public func toggleVisibility() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    @objc private func screenParametersDidChange() {
        refreshGeometry()
    }

    private func refreshGeometry() {
        guard let screen = window.screen ?? NSScreen.main else { return }
        window.reposition(for: screen, heightOverride: heightOverride)

        let diagnosis = DockHealthCheck.diagnose(screen: screen)
        if diagnosis != lastDiagnosis {
            lastDiagnosis = diagnosis
            onHealthChanged?(diagnosis)
        }
    }
}
