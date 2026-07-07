import Foundation

/// Loads, persists, and live-reloads `~/.config/docksheath/config.json5`.
///
/// On parse failure the last-known-good in-memory config is kept so a typo
/// in a hand edit never crashes or blanks out the running app; `onLoadError`
/// is called so the UI layer can surface a non-blocking warning.
public final class ConfigStore {
    public static let shared = ConfigStore()

    public private(set) var config: TaskbarConfig
    public var onConfigChanged: ((TaskbarConfig) -> Void)?
    public var onLoadError: ((Error) -> Void)?

    public let configDirectoryURL: URL
    public let configFileURL: URL

    private var watcher: ConfigFileWatcher?

    public init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        let dir = homeDirectory.appendingPathComponent(".config/docksheath", isDirectory: true)
        self.configDirectoryURL = dir
        self.configFileURL = dir.appendingPathComponent("config.json5")
        self.config = TaskbarConfig()
    }

    /// Ensures the config directory/file exist (copying `defaultConfigTemplate`
    /// in verbatim on first run so its comments double as inline docs), then loads it.
    @discardableResult
    public func loadOrCreateDefault(defaultConfigTemplate: String) -> TaskbarConfig {
        do {
            try FileManager.default.createDirectory(at: configDirectoryURL, withIntermediateDirectories: true)
        } catch {
            onLoadError?(error)
        }

        if !FileManager.default.fileExists(atPath: configFileURL.path) {
            do {
                try defaultConfigTemplate.write(to: configFileURL, atomically: true, encoding: .utf8)
            } catch {
                onLoadError?(error)
            }
        }

        return reload()
    }

    @discardableResult
    public func reload() -> TaskbarConfig {
        do {
            let text = try String(contentsOf: configFileURL, encoding: .utf8)
            let loaded = try TaskbarConfig.parse(json5: text)
            config = loaded
            onConfigChanged?(loaded)
        } catch {
            onLoadError?(error)
        }
        return config
    }

    /// Persists a config change made from the UI (e.g. pinning an app, or
    /// editing Settings) back to disk, and applies it immediately —
    /// `onConfigChanged` is called directly here rather than waiting for
    /// `ConfigFileWatcher` to notice the write and call `reload()`, since
    /// that round trip (disk write → kqueue event → debounce → re-read) is
    /// unnecessary latency/fragility for a change that originated in this
    /// same process. The watcher is still needed and still runs — it's the
    /// only signal for an *external* hand-edit to config.json5 — this just
    /// means an in-app change no longer depends on it too.
    /// Note this rewrites the file as plain JSON, which loses any
    /// hand-written comments — acceptable for MVP since it only happens when
    /// the user actively drives a UI action that mutates config.
    public func save(_ newConfig: TaskbarConfig) {
        config = newConfig
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(newConfig)
            try data.write(to: configFileURL, options: .atomic)
        } catch {
            onLoadError?(error)
        }
        onConfigChanged?(newConfig)
    }

    public func startWatching() {
        guard watcher == nil else { return }
        let newWatcher = ConfigFileWatcher(fileURL: configFileURL) { [weak self] in
            self?.reload()
        }
        watcher = newWatcher
        newWatcher.start()
    }

    public func stopWatching() {
        watcher?.stop()
        watcher = nil
    }
}
