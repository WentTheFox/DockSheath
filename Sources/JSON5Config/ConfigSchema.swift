import Foundation

/// Root schema for DockSheath's `~/.config/docksheath/config.json5`.
public struct TaskbarConfig: Codable, Equatable {
    public var schemaVersion: Int
    public var pinnedApps: [PinnedAppEntry]
    public var taskbar: TaskbarAppearanceConfig
    public var hotkeys: HotkeyConfig
    public var behavior: BehaviorConfig
    public var appearance: AppearanceConfig

    public init(
        schemaVersion: Int = 1,
        pinnedApps: [PinnedAppEntry] = [],
        taskbar: TaskbarAppearanceConfig = TaskbarAppearanceConfig(),
        hotkeys: HotkeyConfig = HotkeyConfig(),
        behavior: BehaviorConfig = BehaviorConfig(),
        appearance: AppearanceConfig = AppearanceConfig()
    ) {
        self.schemaVersion = schemaVersion
        self.pinnedApps = pinnedApps
        self.taskbar = taskbar
        self.hotkeys = hotkeys
        self.behavior = behavior
        self.appearance = appearance
    }
}

public struct PinnedAppEntry: Codable, Equatable, Identifiable {
    public var bundlePath: String
    public var bundleIdentifier: String?

    public var id: String { bundleIdentifier ?? bundlePath }

    public init(bundlePath: String, bundleIdentifier: String? = nil) {
        self.bundlePath = bundlePath
        self.bundleIdentifier = bundleIdentifier
    }
}

public struct TaskbarAppearanceConfig: Codable, Equatable {
    /// When nil, the taskbar height is auto-detected from the system Dock's
    /// reserved screen inset rather than a fixed value.
    public var heightOverride: Double?

    public init(heightOverride: Double? = nil) {
        self.heightOverride = heightOverride
    }
}

public struct HotkeyConfig: Codable, Equatable {
    public var toggleVisibility: HotKeyBinding?

    public init(toggleVisibility: HotKeyBinding? = .default) {
        self.toggleVisibility = toggleVisibility
    }
}

public struct HotKeyBinding: Codable, Equatable {
    public var keyCode: UInt32
    public var modifiers: [String]

    public init(keyCode: UInt32, modifiers: [String]) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// Command+Option+D — the default taskbar show/hide toggle.
    public static let `default` = HotKeyBinding(keyCode: 2, modifiers: ["command", "option"])
}

public struct BehaviorConfig: Codable, Equatable {
    public var autoHideOnMouseLeave: Bool
    public var showOnAllDisplays: Bool
    public var groupWindowsByApp: Bool
    public var refreshIntervalMs: Int

    public init(
        autoHideOnMouseLeave: Bool = false,
        showOnAllDisplays: Bool = false,
        groupWindowsByApp: Bool = true,
        refreshIntervalMs: Int = 1500
    ) {
        self.autoHideOnMouseLeave = autoHideOnMouseLeave
        self.showOnAllDisplays = showOnAllDisplays
        self.groupWindowsByApp = groupWindowsByApp
        self.refreshIntervalMs = refreshIntervalMs
    }
}

public struct AppearanceConfig: Codable, Equatable {
    public var theme: String
    public var accentColor: String?
    public var iconSize: Double
    public var showAppLabels: Bool

    public init(
        theme: String = "auto",
        accentColor: String? = nil,
        iconSize: Double = 32,
        showAppLabels: Bool = false
    ) {
        self.theme = theme
        self.accentColor = accentColor
        self.iconSize = iconSize
        self.showAppLabels = showAppLabels
    }
}

extension TaskbarConfig {
    public enum ParseError: Error, CustomStringConvertible {
        case invalidUTF8
        case decodingFailed(String)

        public var description: String {
            switch self {
            case .invalidUTF8:
                return "Config file is not valid UTF-8"
            case .decodingFailed(let message):
                return message
            }
        }
    }

    /// Parses a restricted-JSON5 config document (see `JSON5Preprocessor`).
    public static func parse(json5 text: String) throws -> TaskbarConfig {
        let jsonText = try JSON5Preprocessor.preprocess(text)
        guard let data = jsonText.data(using: .utf8) else {
            throw ParseError.invalidUTF8
        }
        do {
            return try JSONDecoder().decode(TaskbarConfig.self, from: data)
        } catch {
            throw ParseError.decodingFailed("Failed to parse config.json5: \(error)")
        }
    }
}
