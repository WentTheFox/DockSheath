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

    // Swift's synthesized Decodable requires every key to be present for
    // non-optional properties — it does NOT fall back to the memberwise
    // initializer's default values. A custom decoder is needed so a config
    // file that only sets a few fields (or is empty) still loads correctly.
    private enum CodingKeys: String, CodingKey {
        case schemaVersion, pinnedApps, taskbar, hotkeys, behavior, appearance
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        pinnedApps = try container.decodeIfPresent([PinnedAppEntry].self, forKey: .pinnedApps) ?? []
        taskbar = try container.decodeIfPresent(TaskbarAppearanceConfig.self, forKey: .taskbar) ?? TaskbarAppearanceConfig()
        hotkeys = try container.decodeIfPresent(HotkeyConfig.self, forKey: .hotkeys) ?? HotkeyConfig()
        behavior = try container.decodeIfPresent(BehaviorConfig.self, forKey: .behavior) ?? BehaviorConfig()
        appearance = try container.decodeIfPresent(AppearanceConfig.self, forKey: .appearance) ?? AppearanceConfig()
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
    /// The taskbar's thickness along its short axis — height when the Dock
    /// (and therefore the taskbar) is at the bottom, width when it's on the
    /// left or right. When nil, it's auto-detected from the system Dock's
    /// reserved screen inset rather than a fixed value.
    public var sizeOverride: Double?

    public init(sizeOverride: Double? = nil) {
        self.sizeOverride = sizeOverride
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

    private enum CodingKeys: String, CodingKey {
        case autoHideOnMouseLeave, showOnAllDisplays, groupWindowsByApp, refreshIntervalMs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        autoHideOnMouseLeave = try container.decodeIfPresent(Bool.self, forKey: .autoHideOnMouseLeave) ?? false
        showOnAllDisplays = try container.decodeIfPresent(Bool.self, forKey: .showOnAllDisplays) ?? false
        groupWindowsByApp = try container.decodeIfPresent(Bool.self, forKey: .groupWindowsByApp) ?? true
        refreshIntervalMs = try container.decodeIfPresent(Int.self, forKey: .refreshIntervalMs) ?? 1500
    }
}

public struct AppearanceConfig: Codable, Equatable {
    public var theme: String
    public var accentColor: String?
    public var iconSize: Double
    public var showAppLabels: Bool
    public var taskbarColors: TaskbarColorOverrides
    public var buttonColors: ButtonColorOverrides

    public init(
        theme: String = "auto",
        accentColor: String? = nil,
        iconSize: Double = 32,
        showAppLabels: Bool = false,
        taskbarColors: TaskbarColorOverrides = TaskbarColorOverrides(),
        buttonColors: ButtonColorOverrides = ButtonColorOverrides()
    ) {
        self.theme = theme
        self.accentColor = accentColor
        self.iconSize = iconSize
        self.showAppLabels = showAppLabels
        self.taskbarColors = taskbarColors
        self.buttonColors = buttonColors
    }

    private enum CodingKeys: String, CodingKey {
        case theme, accentColor, iconSize, showAppLabels, taskbarColors, buttonColors
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        theme = try container.decodeIfPresent(String.self, forKey: .theme) ?? "auto"
        accentColor = try container.decodeIfPresent(String.self, forKey: .accentColor)
        iconSize = try container.decodeIfPresent(Double.self, forKey: .iconSize) ?? 32
        showAppLabels = try container.decodeIfPresent(Bool.self, forKey: .showAppLabels) ?? false
        taskbarColors = try container.decodeIfPresent(TaskbarColorOverrides.self, forKey: .taskbarColors) ?? TaskbarColorOverrides()
        buttonColors = try container.decodeIfPresent(ButtonColorOverrides.self, forKey: .buttonColors) ?? ButtonColorOverrides()
    }
}

/// Hex color overrides (e.g. `"#RRGGBB"` or `"#RRGGBBAA"`) for the taskbar's
/// own background/border. Leaving a field `null` (the default) means "follow
/// the system light/dark appearance" instead of a fixed color. The taskbar
/// itself has no text of its own, so there's no `text` field here — see
/// `ButtonColorOverrides` for the taskbar buttons' text color.
public struct TaskbarColorOverrides: Codable, Equatable {
    public var background: String?
    public var border: String?

    public init(background: String? = nil, border: String? = nil) {
        self.background = background
        self.border = border
    }
}

/// Hex color overrides for the taskbar buttons (pinned apps, running
/// windows, and the Quick Launch button). Every field is optional and
/// `null` by default, meaning "follow the system appearance/accent color".
public struct ButtonColorOverrides: Codable, Equatable {
    public var background: String?
    public var border: String?
    public var text: String?

    public init(background: String? = nil, border: String? = nil, text: String? = nil) {
        self.background = background
        self.border = border
        self.text = text
    }
}

extension TaskbarConfig {
    public enum ParseError: Error, CustomStringConvertible {
        case decodingFailed(String)

        public var description: String {
            switch self {
            case .decodingFailed(let message):
                return message
            }
        }
    }

    /// Parses a full JSON5 document (see `JSON5Parser`) and decodes it into
    /// a `TaskbarConfig`. The JSON5 value tree is converted to plain
    /// Foundation types and re-serialized as standard JSON so `JSONDecoder`
    /// (and this type's custom `init(from:)` default-value handling) can do
    /// the typed decoding unchanged.
    public static func parse(json5 text: String) throws -> TaskbarConfig {
        let value: JSON5Value
        do {
            value = try JSON5Parser.parse(text)
        } catch {
            throw ParseError.decodingFailed("Failed to parse config.json5: \(error)")
        }

        guard case .object = value else {
            throw ParseError.decodingFailed("Failed to parse config.json5: the top-level value must be an object")
        }

        let foundationValue = value.toFoundation()
        guard JSONSerialization.isValidJSONObject(foundationValue) else {
            throw ParseError.decodingFailed(
                "Failed to parse config.json5: contains a value (e.g. Infinity or NaN) that isn't representable in standard JSON"
            )
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: foundationValue)
            return try JSONDecoder().decode(TaskbarConfig.self, from: data)
        } catch {
            throw ParseError.decodingFailed("Failed to parse config.json5: \(error)")
        }
    }
}
