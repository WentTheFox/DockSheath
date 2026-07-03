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
    private var hotKey: GlobalHotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        ConfigStore.shared.onConfigChanged = { [weak self] config in
            self?.applyConfig(config)
        }
        ConfigStore.shared.loadOrCreateDefault(defaultConfigTemplate: Self.bundledDefaultConfigText())
        ConfigStore.shared.startWatching()

        if PermissionChecks.isAccessibilityTrusted {
            startCore()
        } else {
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

    private func showOnboarding() {
        let controller = PermissionsOnboardingWindowController { [weak self] in
            self?.startCore()
        }
        onboardingWindowController = controller
        controller.showAndActivate()
    }

    private func startCore() {
        guard primaryInstance == nil else { return }

        let primaryScreen = SecondaryDisplayManager.detectPrimaryDockScreen()
        let primary = TaskbarInstance(
            screen: primaryScreen,
            displayNumber: SecondaryDisplayManager.displayNumber(for: primaryScreen),
            reservationStrategy: .followRealDock
        )
        primaryInstance = primary

        let statusItem = StatusItemController(overlayController: primary.overlay)
        statusItemController = statusItem
        primary.overlay.onHealthChanged = { [weak statusItem] diagnosis in
            statusItem?.updateDockHealth(diagnosis)
        }

        let secondary = SecondaryDisplayManager(primaryScreen: primaryScreen)
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
