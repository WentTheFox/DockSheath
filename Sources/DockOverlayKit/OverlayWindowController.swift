import AppKit

/// Owns the DockSheath overlay window's lifecycle: keeps it sized/positioned
/// to match the Dock's reserved space on whichever edge it's on, reacts to
/// screen changes, exposes a show/hide toggle independent of the
/// space-reservation logic, and reports Dock health-check diagnoses and edge
/// changes so the UI can warn the user / re-lay itself out.
///
/// When the real Dock is set to auto-hide, it doesn't reserve any screen
/// space at all — macOS treats its hover-reveal as a temporary overlay, not
/// a layout change — so there's nothing to statically cover. In that case
/// this controller mirrors the Dock's own behavior instead: the taskbar
/// stays hidden until the mouse reaches the relevant screen edge, then
/// hides again shortly after the mouse moves away.
public final class OverlayWindowController {
    /// How this controller decides what screen space to reserve/cover.
    public enum ReservationStrategy {
        /// Detect and cover the real Dock's reserved screen space — the
        /// default, and the only strategy that gets genuine OS-level space
        /// reservation for free via `NSScreen.visibleFrame`.
        case followRealDock
        /// Reserve a fixed strip on the given edge regardless of what (if
        /// anything) macOS itself has reserved there. Used for secondary
        /// displays that don't have their own real Dock — nothing at the OS
        /// level reserves space there automatically, so callers using this
        /// strategy are expected to separately enforce the boundary against
        /// other windows (see `DockSheath`'s `SecondaryDisplayManager`).
        case fixed(edge: DockEdge)
    }

    public let window: OverlayWindow
    public var sizeOverride: CGFloat?
    public var reservationStrategy: ReservationStrategy
    public var onHealthChanged: ((DockHealthCheck.Diagnosis) -> Void)?
    public var onReservationChanged: ((DockReservation) -> Void)?

    /// How close (in points) the mouse must get to the screen edge to
    /// trigger a reveal while mirroring an auto-hidden Dock.
    public var autoRevealThreshold: CGFloat = 4
    /// How long the mouse must stay away from the edge/taskbar before it's
    /// concealed again while mirroring an auto-hidden Dock.
    public var autoConcealDelay: TimeInterval = 0.4
    /// How often to re-check the Dock's reserved size as a fallback, in case
    /// `NSApplication.didChangeScreenParametersNotification` doesn't fire
    /// promptly for every step of a live Dock icon-size drag in System
    /// Settings. `refreshGeometry()` always reads the live `visibleFrame`,
    /// so this just bounds how stale the taskbar's size can get, not how
    /// stale the underlying data is.
    public var geometryPollInterval: TimeInterval = 1.0

    private var lastDiagnosis: DockHealthCheck.Diagnosis?
    private var lastEdge: DockEdge?
    private var isMirroringAutoHide = false
    private var mouseMonitors: [Any] = []
    private var concealWorkItem: DispatchWorkItem?
    private var geometryPollTimer: Timer?

    private static let defaultAutoRevealThickness: CGFloat = 70

    public init(
        contentViewController: NSViewController,
        screen: NSScreen? = nil,
        reservationStrategy: ReservationStrategy = .followRealDock
    ) {
        self.reservationStrategy = reservationStrategy
        let targetScreen = screen ?? NSScreen.main ?? NSScreen.screens[0]
        let initialEdge: DockEdge
        if case .fixed(let edge) = reservationStrategy {
            initialEdge = edge
        } else {
            initialEdge = .bottom
        }
        let initialReservation = DockGeometry.currentReservation(for: targetScreen)
            ?? Self.fallbackReservation(for: targetScreen, edge: initialEdge)
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

        geometryPollTimer = Timer.scheduledTimer(withTimeInterval: geometryPollInterval, repeats: true) { [weak self] _ in
            self?.refreshGeometry()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        geometryPollTimer?.invalidate()
        stopMouseMonitoring()
    }

    public func start() {
        refreshGeometry()
        if !isMirroringAutoHide {
            window.orderFrontRegardless()
        }
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

        switch reservationStrategy {
        case .followRealDock:
            if DockHealthCheck.isAutoHideEnabled() {
                enterAutoHideMirroringIfNeeded(screen: screen)
            } else {
                exitAutoHideMirroringIfNeeded()
                let reservation = DockGeometry.currentReservation(for: screen, sizeOverride: sizeOverride)
                    ?? Self.fallbackReservation(for: screen, edge: lastEdge ?? .bottom)
                window.reposition(to: reservation)
                reportEdgeIfChanged(reservation.edge, rect: reservation.rect)
            }

            let diagnosis = DockHealthCheck.diagnose(screen: screen)
            if diagnosis != lastDiagnosis {
                lastDiagnosis = diagnosis
                onHealthChanged?(diagnosis)
            }

        case .fixed(let edge):
            // No OS-level reservation exists to detect (or diagnose) on a
            // screen without a real Dock, so this always just re-measures
            // the fixed strip at the current thickness/screen size.
            let thickness = sizeOverride ?? DockGeometry.dockTileSizePreference() ?? Self.defaultAutoRevealThickness
            let reservation = Self.fallbackReservation(for: screen, edge: edge, thickness: thickness)
            window.reposition(to: reservation)
            reportEdgeIfChanged(reservation.edge, rect: reservation.rect)
        }
    }

    private func reportEdgeIfChanged(_ edge: DockEdge, rect: NSRect) {
        guard edge != lastEdge else { return }
        lastEdge = edge
        onReservationChanged?(DockReservation(edge: edge, rect: rect))
    }

    // MARK: - Auto-hide mirroring

    private func enterAutoHideMirroringIfNeeded(screen: NSScreen) {
        guard !isMirroringAutoHide else { return }
        isMirroringAutoHide = true
        window.orderOut(nil) // conceal immediately, matching the hidden real Dock
        startMouseMonitoring()

        // Even while hidden, the edge is still needed so the taskbar UI lays
        // itself out correctly once revealed — visibleFrame gives no signal
        // here, so fall back to the Dock's orientation preference directly.
        let edge = DockGeometry.dockOrientationPreference() ?? lastEdge ?? .bottom
        reportEdgeIfChanged(edge, rect: Self.fallbackReservation(for: screen, edge: edge).rect)
    }

    private func exitAutoHideMirroringIfNeeded() {
        guard isMirroringAutoHide else { return }
        isMirroringAutoHide = false
        stopMouseMonitoring()
        // Mirroring mode always leaves the window concealed when it isn't
        // actively being hovered-open; normal (non-mirroring) mode expects
        // the taskbar to be visible by default, so re-show it here. Without
        // this, toggling Dock auto-hide off while the taskbar happened to be
        // concealed at that instant would leave it stuck hidden forever.
        window.orderFrontRegardless()
    }

    private func startMouseMonitoring() {
        guard mouseMonitors.isEmpty else { return }

        // Trailing closures are deliberately not used here: `if let x = f() { ... }`
        // is ambiguous between the closure being f()'s argument or the if-body,
        // so the handler is passed explicitly instead.
        let globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved],
            handler: { [weak self] _ in self?.handleMouseMoved() }
        )
        if let globalMonitor {
            mouseMonitors.append(globalMonitor)
        }

        let localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved],
            handler: { [weak self] event in
                self?.handleMouseMoved()
                return event
            }
        )
        if let localMonitor {
            mouseMonitors.append(localMonitor)
        }
    }

    private func stopMouseMonitoring() {
        mouseMonitors.forEach(NSEvent.removeMonitor)
        mouseMonitors.removeAll()
        concealWorkItem?.cancel()
    }

    private func handleMouseMoved() {
        guard isMirroringAutoHide, let screen = window.screen ?? NSScreen.main else { return }

        let location = NSEvent.mouseLocation
        let edge = lastEdge ?? .bottom

        let nearEdgeStrip: Bool
        switch edge {
        case .bottom:
            nearEdgeStrip = location.y - screen.frame.minY <= autoRevealThreshold
        case .left:
            nearEdgeStrip = location.x - screen.frame.minX <= autoRevealThreshold
        case .right:
            nearEdgeStrip = screen.frame.maxX - location.x <= autoRevealThreshold
        }

        // Once revealed, staying over the taskbar itself (not just the thin
        // initial edge strip) keeps it shown — otherwise it would try to
        // conceal itself the moment the mouse moves up to click something.
        let overTaskbar = window.isVisible && window.frame.insetBy(dx: -4, dy: -4).contains(location)

        if nearEdgeStrip || overTaskbar {
            concealWorkItem?.cancel()
            guard !window.isVisible else { return }
            let thickness = sizeOverride ?? DockGeometry.dockTileSizePreference() ?? Self.defaultAutoRevealThickness
            window.reposition(to: Self.fallbackReservation(for: screen, edge: edge, thickness: thickness))
            window.orderFrontRegardless()
        } else if window.isVisible {
            scheduleConceal()
        }
    }

    private func scheduleConceal() {
        concealWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.window.orderOut(nil)
        }
        concealWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + autoConcealDelay, execute: work)
    }

    /// Used when there's no real reservation to measure (Dock auto-hidden,
    /// or genuinely missing) so the window still has sensible geometry on
    /// the last-known edge. `thickness` defaults to 0 (effectively
    /// invisible) for the "nothing to show" case, or a real value when
    /// temporarily revealing to mirror an auto-hidden Dock.
    private static func fallbackReservation(for screen: NSScreen, edge: DockEdge, thickness: CGFloat = 0) -> DockReservation {
        let frame = screen.frame
        let topInset = max(0, frame.maxY - screen.visibleFrame.maxY)
        let rect: NSRect
        switch edge {
        case .bottom:
            rect = NSRect(x: frame.minX, y: frame.minY, width: frame.width, height: thickness)
        case .left:
            rect = NSRect(x: frame.minX, y: frame.minY, width: thickness, height: frame.height - topInset)
        case .right:
            rect = NSRect(x: frame.maxX - thickness, y: frame.minY, width: thickness, height: frame.height - topInset)
        }
        return DockReservation(edge: edge, rect: rect)
    }
}
