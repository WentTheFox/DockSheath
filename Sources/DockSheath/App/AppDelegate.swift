import AppKit
import DockOverlayKit
import AXWindowKit
import JSON5Config
import TaskbarUI
import GlobalHotKey

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlayController: OverlayWindowController?
    private var statusItemController: StatusItemController?
    private var taskbarViewController: TaskbarViewController?
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
        guard overlayController == nil else { return }

        let taskbarVC = TaskbarViewController()
        taskbarViewController = taskbarVC

        let overlay = OverlayWindowController(contentViewController: taskbarVC)
        overlayController = overlay

        let statusItem = StatusItemController(overlayController: overlay)
        statusItemController = statusItem
        overlay.onHealthChanged = { [weak statusItem] diagnosis in
            statusItem?.updateDockHealth(diagnosis)
        }
        overlay.onReservationChanged = { [weak taskbarVC] reservation in
            taskbarVC?.updateLayout(for: reservation.edge)
        }

        taskbarVC.onPinnedAppsChanged = { pinnedApps in
            var updated = ConfigStore.shared.config
            updated.pinnedApps = pinnedApps
            ConfigStore.shared.save(updated)
        }

        applyConfig(ConfigStore.shared.config)
        overlay.start()
    }

    private func applyConfig(_ config: TaskbarConfig) {
        taskbarViewController?.theme = TaskbarTheme.resolve(config.appearance)
        taskbarViewController?.pinnedApps = config.pinnedApps
        overlayController?.sizeOverride = config.taskbar.sizeOverride.map { CGFloat($0) }
        registerHotKey(binding: config.hotkeys.toggleVisibility)
    }

    private func registerHotKey(binding: HotKeyBinding?) {
        hotKey = nil
        guard let binding else { return }
        hotKey = GlobalHotKey(binding: binding) { [weak self] in
            self?.overlayController?.toggleVisibility()
        }
    }
}
