import Combine
import Foundation
import JSON5Config

/// Bridges `TaskbarConfig` to SwiftUI for the Settings window: an
/// `ObservableObject` the views bind directly to, which persists any change
/// back through `ConfigStore` (debounced, so a text field doesn't rewrite the
/// config file on every keystroke).
///
/// Saving goes through the same `ConfigStore.save(_:)` used by pinning/
/// unpinning an app from the taskbar UI, which applies the change to the
/// running taskbar immediately (`onConfigChanged` → `AppDelegate.applyConfig`)
/// as well as persisting it to disk — edits here take effect right away,
/// with no dependency on `ConfigFileWatcher` noticing the write: `ConfigStore
/// .shared.config` is intentionally not re-observed here, since this object
/// is the authoritative source of truth for the config for as long as the
/// window stays open.
enum SettingsTab: Hashable {
    case general, appearance, secondaryDisplay, hotkey, pinnedApps
}

final class SettingsModel: ObservableObject {
    @Published var config: TaskbarConfig {
        didSet { scheduleSave() }
    }
    /// Not part of `TaskbarConfig` — transient UI state so
    /// `SettingsWindowController` can jump to a specific tab (e.g. opening
    /// straight to Pinned Apps from the Quick Launch menu's "Manage Pinned
    /// Apps…" item) without needing `SettingsView`'s own `@State`, which a
    /// window controller can't reach after the view's already been built.
    @Published var selectedTab: SettingsTab = .general

    private var saveWorkItem: DispatchWorkItem?
    private static let saveDebounce: TimeInterval = 0.3

    init() {
        config = ConfigStore.shared.config
    }

    private func scheduleSave() {
        saveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            ConfigStore.shared.save(self.config)
        }
        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.saveDebounce, execute: work)
    }
}
