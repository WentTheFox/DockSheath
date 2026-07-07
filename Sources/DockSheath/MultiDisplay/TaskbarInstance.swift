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

    /// Whether `config.secondaryDisplay`'s overrides apply to this instance
    /// — true for every screen except the one following the real Dock.
    /// Derived from the reservation strategy rather than stored separately,
    /// since the two are always in lockstep (see `OverlayWindowController
    /// .ReservationStrategy`).
    private var isSecondary: Bool {
        if case .fixed = overlay.reservationStrategy { return true }
        return false
    }

    init(
        screen: NSScreen,
        displayNumber: Int,
        reservationStrategy: OverlayWindowController.ReservationStrategy,
        onManagePinnedApps: @escaping () -> Void
    ) {
        let viewController = TaskbarViewController()
        self.viewController = viewController
        viewController.displayNumber = displayNumber
        overlay = OverlayWindowController(
            contentViewController: viewController,
            screen: screen,
            reservationStrategy: reservationStrategy
        )
        viewController.isPrimaryDisplay = !isSecondary
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
        // Same reasoning as onPinnedAppsChanged above: every taskbar instance
        // shares one persisted quickLaunchFavorites list, since the Quick
        // Launch menu (unlike the pinned-apps strip) isn't hidden on
        // secondary-display instances.
        viewController.onQuickLaunchFavoritesChanged = { favorites in
            var updated = ConfigStore.shared.config
            updated.quickLaunchFavorites = favorites
            ConfigStore.shared.save(updated)
        }
        viewController.onManagePinnedApps = onManagePinnedApps
    }

    func apply(config: TaskbarConfig) {
        let effectiveAppearance = isSecondary
            ? config.appearance.applying(config.secondaryDisplay.appearance)
            : config.appearance
        let effectiveTaskbar = isSecondary
            ? config.taskbar.applying(config.secondaryDisplay.taskbar)
            : config.taskbar

        viewController.theme = TaskbarTheme.resolve(effectiveAppearance)
        viewController.showAppLabels = effectiveAppearance.showAppLabels
        viewController.groupWindowsByApp = config.behavior.groupWindowsByApp
        viewController.iconSize = CGFloat(effectiveAppearance.iconSize)
        viewController.refreshIntervalSeconds = TimeInterval(config.behavior.refreshIntervalMs) / 1000
        viewController.pinnedApps = config.pinnedApps
        viewController.quickLaunchFavorites = config.quickLaunchFavorites
        viewController.showDisplayNumber = effectiveAppearance.showDisplayNumber
        viewController.clockConfig = effectiveAppearance.clock
        overlay.sizeOverride = effectiveTaskbar.sizeOverride.map { CGFloat($0) }
    }

    func start() {
        overlay.start()
    }

    func toggleVisibility() {
        overlay.toggleVisibility()
    }
}
