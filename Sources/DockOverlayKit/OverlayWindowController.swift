import AppKit

/// Owns the DockSheath overlay window's lifecycle: keeps it sized/positioned
/// to match the Dock's reserved space on whichever edge it's on, reacts to
/// screen changes, exposes a show/hide toggle independent of the
/// space-reservation logic, and reports Dock health-check diagnoses and edge
/// changes so the UI can warn the user / re-lay itself out.
public final class OverlayWindowController {
    public let window: OverlayWindow
    public var sizeOverride: CGFloat?
    public var onHealthChanged: ((DockHealthCheck.Diagnosis) -> Void)?
    public var onReservationChanged: ((DockReservation) -> Void)?

    private var lastDiagnosis: DockHealthCheck.Diagnosis?
    private var lastEdge: DockEdge?

    public init(contentViewController: NSViewController, screen: NSScreen? = nil) {
        let targetScreen = screen ?? NSScreen.main ?? NSScreen.screens[0]
        let initialReservation = DockGeometry.currentReservation(for: targetScreen)
            ?? Self.fallbackReservation(for: targetScreen, edge: .bottom)
        window = OverlayWindow(reservation: initialReservation)
        window.contentViewController = contentViewController
        // lastEdge is deliberately left nil (not set to initialReservation.edge)
        // so the first refreshGeometry() call always sees it as a change and
        // notifies onReservationChanged — otherwise a non-bottom starting
        // edge would size the window correctly but never tell the content
        // view controller to lay itself out vertically.

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
        let reservation = DockGeometry.currentReservation(for: screen, sizeOverride: sizeOverride)
            ?? Self.fallbackReservation(for: screen, edge: lastEdge ?? .bottom)
        window.reposition(to: reservation)

        if reservation.edge != lastEdge {
            lastEdge = reservation.edge
            onReservationChanged?(reservation)
        }

        let diagnosis = DockHealthCheck.diagnose(screen: screen)
        if diagnosis != lastDiagnosis {
            lastDiagnosis = diagnosis
            onHealthChanged?(diagnosis)
        }
    }

    /// Used when the Dock isn't reserving any space at all (e.g. auto-hidden)
    /// so the window still has a sensible (zero-thickness, effectively
    /// invisible) geometry on the last-known edge rather than an undefined one.
    private static func fallbackReservation(for screen: NSScreen, edge: DockEdge) -> DockReservation {
        let frame = screen.frame
        let rect: NSRect
        switch edge {
        case .bottom:
            rect = NSRect(x: frame.minX, y: frame.minY, width: frame.width, height: 0)
        case .left:
            rect = NSRect(x: frame.minX, y: frame.minY, width: 0, height: frame.height)
        case .right:
            rect = NSRect(x: frame.maxX, y: frame.minY, width: 0, height: frame.height)
        }
        return DockReservation(edge: edge, rect: rect)
    }
}
