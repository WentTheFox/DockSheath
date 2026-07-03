import AppKit
import DockOverlayKit
import TaskbarUI
import JSON5Config

/// A single taskbar's view controller + overlay window pair, plus the glue
/// that keeps the view controller's layout orientation in sync with the
/// overlay's detected/assigned edge. Used once for the primary
/// (real-Dock-following) screen, and once per secondary screen when
/// `behavior.showOnAllDisplays` is enabled — see `SecondaryDisplayManager`.
final class TaskbarInstance {
    let viewController: TaskbarViewController
    let overlay: OverlayWindowController

    init(screen: NSScreen, reservationStrategy: OverlayWindowController.ReservationStrategy) {
        let viewController = TaskbarViewController()
        self.viewController = viewController
        overlay = OverlayWindowController(
            contentViewController: viewController,
            screen: screen,
            reservationStrategy: reservationStrategy
        )
        overlay.onReservationChanged = { [weak viewController] reservation in
            viewController?.updateLayout(for: reservation.edge)
        }
        // Every taskbar instance (primary or secondary) shows/edits the same
        // pinned-apps list, so unpinning from any of them persists the same
        // way.
        viewController.onPinnedAppsChanged = { pinnedApps in
            var updated = ConfigStore.shared.config
            updated.pinnedApps = pinnedApps
            ConfigStore.shared.save(updated)
        }
    }

    func apply(config: TaskbarConfig) {
        viewController.theme = TaskbarTheme.resolve(config.appearance)
        viewController.showAppLabels = config.appearance.showAppLabels
        viewController.groupWindowsByApp = config.behavior.groupWindowsByApp
        viewController.pinnedApps = config.pinnedApps
        overlay.sizeOverride = config.taskbar.sizeOverride.map { CGFloat($0) }
    }

    func start() {
        overlay.start()
    }

    func toggleVisibility() {
        overlay.toggleVisibility()
    }
}
