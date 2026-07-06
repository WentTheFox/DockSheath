import AppKit
import DockOverlayKit
import AXWindowKit
import JSON5Config
import GlobalHotKey

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var primaryInstance: TaskbarInstance?
    private var secondaryDisplays: SecondaryDisplayManager?
    private var statusItemController: StatusItemController?
    private var onboardingWindowController: PermissionsOnboardingWindowController?
    private var settingsWindowController: SettingsWindowController?
    private var hotKey: GlobalHotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Created up front, before permissions are even checked: with no
        // Dock icon (.accessory) and no status item, closing the onboarding
        // window would leave the app running with no way to reopen it or
        // quit.
        let statusItem = StatusItemController()
        statusItemController = statusItem
        statusItem.onOpenSettings = { [weak self] in self?.showSettings() }

        ConfigStore.shared.onConfigChanged = { [weak self] config in
            self?.applyConfig(config)
        }
        ConfigStore.shared.loadOrCreateDefault(defaultConfigTemplate: Self.bundledDefaultConfigText())
        ConfigStore.shared.startWatching()

        if PermissionChecks.isAccessibilityTrusted {
            startCore()
        } else {
            statusItem.showPendingSetup { [weak self] in self?.showOnboarding() }
            showOnboarding()
        }
    }

    private static func bundledDefaultConfigText() -> String {
        guard let url = Bundle.module.url(forResource: "DefaultConfig", withExtension: "json5", subdirectory: "Resources"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return "{ \"schemaVersion\": 1 }\n"
        }
        return text
    }

    /// Reuses the existing onboarding window/controller if one's already
    /// been created (e.g. re-shown via the status item's "Open Setup…" after
    /// the user closed it) rather than creating a second one.
    private func showOnboarding() {
        if let existing = onboardingWindowController {
            existing.showAndActivate()
            return
        }
        let controller = PermissionsOnboardingWindowController { [weak self] in
            self?.startCore()
        }
        onboardingWindowController = controller
        controller.showAndActivate()
    }

    /// Reuses the existing Settings window/controller if one's already open,
    /// same as `showOnboarding()`.
    private func showSettings(selecting tab: SettingsTab? = nil) {
        if let existing = settingsWindowController {
            existing.showAndActivate(selecting: tab)
            return
        }
        let controller = SettingsWindowController()
        settingsWindowController = controller
        controller.showAndActivate(selecting: tab)
    }

    private func startCore() {
        guard primaryInstance == nil else { return }

        let primaryScreen = SecondaryDisplayManager.detectPrimaryDockScreen()
        let primary = TaskbarInstance(
            screen: primaryScreen,
            displayNumber: SecondaryDisplayManager.displayNumber(for: primaryScreen),
            reservationStrategy: .followRealDock,
            onManagePinnedApps: { [weak self] in self?.showSettings(selecting: .pinnedApps) }
        )
        primaryInstance = primary

        // Always non-nil by this point — created up front in
        // applicationDidFinishLaunching().
        let statusItem = statusItemController!
        statusItem.showRunning(overlayController: primary.overlay)
        primary.overlay.onHealthChanged = { [weak statusItem] diagnosis in
            statusItem?.updateDockHealth(diagnosis)
        }

        let secondary = SecondaryDisplayManager(
            primaryScreen: primaryScreen,
            onManagePinnedApps: { [weak self] in self?.showSettings(selecting: .pinnedApps) }
        )
        secondaryDisplays = secondary
        statusItem.onAdditionalToggle = { [weak secondary] in
            secondary?.toggleVisibility()
        }

        applyConfig(ConfigStore.shared.config)
        primary.start()
    }

    private func applyConfig(_ config: TaskbarConfig) {
        primaryInstance?.apply(config: config)
        secondaryDisplays?.apply(config: config)
        registerHotKey(binding: config.hotkeys.toggleVisibility)
    }

    private func registerHotKey(binding: HotKeyBinding?) {
        hotKey = nil
        guard let binding else { return }
        hotKey = GlobalHotKey(binding: binding) { [weak self] in
            self?.primaryInstance?.toggleVisibility()
            self?.secondaryDisplays?.toggleVisibility()
        }
    }
}
