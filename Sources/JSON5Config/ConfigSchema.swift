import Foundation

/// Root schema for DockSheath's `~/.config/docksheath/config.json5`.
public struct TaskbarConfig: Codable, Equatable {
    public var schemaVersion: Int
    public var pinnedApps: [PinnedAppEntry]
    public var taskbar: TaskbarAppearanceConfig
    public var hotkeys: HotkeyConfig
    public var behavior: BehaviorConfig
    public var appearance: AppearanceConfig
    /// Overrides applied on top of `taskbar`/`appearance` for every screen
    /// except the one hosting the real Dock, when `behavior.showOnAllDisplays`
    /// is enabled. Any field left unset here falls back to the corresponding
    /// top-level `taskbar`/`appearance` value — see `TaskbarAppearanceConfig
    /// .applying(_:)` / `AppearanceConfig.applying(_:)`.
    public var secondaryDisplay: SecondaryDisplayConfig

    public init(
        schemaVersion: Int = 1,
        pinnedApps: [PinnedAppEntry] = [],
        taskbar: TaskbarAppearanceConfig = TaskbarAppearanceConfig(),
        hotkeys: HotkeyConfig = HotkeyConfig(),
        behavior: BehaviorConfig = BehaviorConfig(),
        appearance: AppearanceConfig = AppearanceConfig(),
        secondaryDisplay: SecondaryDisplayConfig = SecondaryDisplayConfig()
    ) {
        self.schemaVersion = schemaVersion
        self.pinnedApps = pinnedApps
        self.taskbar = taskbar
        self.hotkeys = hotkeys
        self.behavior = behavior
        self.appearance = appearance
        self.secondaryDisplay = secondaryDisplay
    }

    // Swift's synthesized Decodable requires every key to be present for
    // non-optional properties — it does NOT fall back to the memberwise
    // initializer's default values. A custom decoder is needed so a config
    // file that only sets a few fields (or is empty) still loads correctly.
    private enum CodingKeys: String, CodingKey {
        case schemaVersion, pinnedApps, taskbar, hotkeys, behavior, appearance, secondaryDisplay
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        pinnedApps = try container.decodeIfPresent([PinnedAppEntry].self, forKey: .pinnedApps) ?? []
        taskbar = try container.decodeIfPresent(TaskbarAppearanceConfig.self, forKey: .taskbar) ?? TaskbarAppearanceConfig()
        hotkeys = try container.decodeIfPresent(HotkeyConfig.self, forKey: .hotkeys) ?? HotkeyConfig()
        behavior = try container.decodeIfPresent(BehaviorConfig.self, forKey: .behavior) ?? BehaviorConfig()
        appearance = try container.decodeIfPresent(AppearanceConfig.self, forKey: .appearance) ?? AppearanceConfig()
        secondaryDisplay = try container.decodeIfPresent(SecondaryDisplayConfig.self, forKey: .secondaryDisplay) ?? SecondaryDisplayConfig()
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

    /// Returns a copy with any non-nil field in `overrides` replacing this
    /// value's own — used to resolve a secondary display's effective
    /// taskbar config from `secondaryDisplay.taskbar` + the top-level
    /// `taskbar`.
    public func applying(_ overrides: TaskbarAppearanceOverrides) -> TaskbarAppearanceConfig {
        TaskbarAppearanceConfig(sizeOverride: overrides.sizeOverride ?? sizeOverride)
    }
}

/// Per-field overrides mirroring `TaskbarAppearanceConfig`, for
/// `secondaryDisplay.taskbar`. Every field is `nil` by default, meaning
/// "inherit the top-level `taskbar` value" — see `TaskbarAppearanceConfig
/// .applying(_:)`.
public struct TaskbarAppearanceOverrides: Codable, Equatable {
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
    /// Shows a small badge with this screen's display number (1-based,
    /// following `NSScreen.screens` order) at the taskbar's trailing edge.
    /// Mostly useful once `behavior.showOnAllDisplays` is on and there's more
    /// than one taskbar to tell apart.
    public var showDisplayNumber: Bool
    public var clock: ClockConfig
    /// Font for every taskbar button's label (Start, pinned apps, running
    /// windows).
    public var buttonFont: FontConfig
    /// Font for the display-number badge. Its bold weight is fixed, not
    /// user-configurable — only family/size come from here.
    public var displayNumberFont: FontConfig
    /// Font for the clock. Its medium weight is fixed, not
    /// user-configurable — only family/size come from here.
    public var clockFont: FontConfig

    public init(
        theme: String = "auto",
        accentColor: String? = nil,
        iconSize: Double = 32,
        showAppLabels: Bool = true,
        taskbarColors: TaskbarColorOverrides = TaskbarColorOverrides(),
        buttonColors: ButtonColorOverrides = ButtonColorOverrides(),
        showDisplayNumber: Bool = false,
        clock: ClockConfig = ClockConfig(),
        buttonFont: FontConfig = FontConfig(size: 11),
        displayNumberFont: FontConfig = FontConfig(size: 10),
        clockFont: FontConfig = FontConfig(size: 11)
    ) {
        self.theme = theme
        self.accentColor = accentColor
        self.iconSize = iconSize
        self.showAppLabels = showAppLabels
        self.taskbarColors = taskbarColors
        self.buttonColors = buttonColors
        self.showDisplayNumber = showDisplayNumber
        self.clock = clock
        self.buttonFont = buttonFont
        self.displayNumberFont = displayNumberFont
        self.clockFont = clockFont
    }

    private enum CodingKeys: String, CodingKey {
        case theme, accentColor, iconSize, showAppLabels, taskbarColors, buttonColors, showDisplayNumber, clock
        case buttonFont, displayNumberFont, clockFont
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        theme = try container.decodeIfPresent(String.self, forKey: .theme) ?? "auto"
        accentColor = try container.decodeIfPresent(String.self, forKey: .accentColor)
        iconSize = try container.decodeIfPresent(Double.self, forKey: .iconSize) ?? 32
        showAppLabels = try container.decodeIfPresent(Bool.self, forKey: .showAppLabels) ?? true
        taskbarColors = try container.decodeIfPresent(TaskbarColorOverrides.self, forKey: .taskbarColors) ?? TaskbarColorOverrides()
        buttonColors = try container.decodeIfPresent(ButtonColorOverrides.self, forKey: .buttonColors) ?? ButtonColorOverrides()
        showDisplayNumber = try container.decodeIfPresent(Bool.self, forKey: .showDisplayNumber) ?? false
        clock = try container.decodeIfPresent(ClockConfig.self, forKey: .clock) ?? ClockConfig()
        buttonFont = try container.decodeIfPresent(FontConfig.self, forKey: .buttonFont) ?? FontConfig(size: 11)
        displayNumberFont = try container.decodeIfPresent(FontConfig.self, forKey: .displayNumberFont) ?? FontConfig(size: 10)
        clockFont = try container.decodeIfPresent(FontConfig.self, forKey: .clockFont) ?? FontConfig(size: 11)
    }

    /// Returns a copy with any non-nil field in `overrides` replacing this
    /// value's own — used to resolve a secondary display's effective
    /// appearance from `secondaryDisplay.appearance` + the top-level
    /// `appearance`. `taskbarColors`/`buttonColors`/`clock`/the font configs
    /// are replaced as whole structs when overridden, not merged
    /// field-by-field.
    public func applying(_ overrides: AppearanceOverrides) -> AppearanceConfig {
        AppearanceConfig(
            theme: overrides.theme ?? theme,
            accentColor: overrides.accentColor ?? accentColor,
            iconSize: overrides.iconSize ?? iconSize,
            showAppLabels: overrides.showAppLabels ?? showAppLabels,
            taskbarColors: overrides.taskbarColors ?? taskbarColors,
            buttonColors: overrides.buttonColors ?? buttonColors,
            showDisplayNumber: overrides.showDisplayNumber ?? showDisplayNumber,
            clock: overrides.clock ?? clock,
            buttonFont: overrides.buttonFont ?? buttonFont,
            displayNumberFont: overrides.displayNumberFont ?? displayNumberFont,
            clockFont: overrides.clockFont ?? clockFont
        )
    }
}

/// Per-field overrides mirroring `AppearanceConfig`, for
/// `secondaryDisplay.appearance`. Every field is `nil` by default, meaning
/// "inherit the top-level `appearance` value" — see `AppearanceConfig
/// .applying(_:)`.
public struct AppearanceOverrides: Codable, Equatable {
    public var theme: String?
    public var accentColor: String?
    public var iconSize: Double?
    public var showAppLabels: Bool?
    public var taskbarColors: TaskbarColorOverrides?
    public var buttonColors: ButtonColorOverrides?
    public var showDisplayNumber: Bool?
    public var clock: ClockConfig?
    public var buttonFont: FontConfig?
    public var displayNumberFont: FontConfig?
    public var clockFont: FontConfig?

    public init(
        theme: String? = nil,
        accentColor: String? = nil,
        iconSize: Double? = nil,
        showAppLabels: Bool? = nil,
        taskbarColors: TaskbarColorOverrides? = nil,
        buttonColors: ButtonColorOverrides? = nil,
        showDisplayNumber: Bool? = nil,
        clock: ClockConfig? = nil,
        buttonFont: FontConfig? = nil,
        displayNumberFont: FontConfig? = nil,
        clockFont: FontConfig? = nil
    ) {
        self.theme = theme
        self.accentColor = accentColor
        self.iconSize = iconSize
        self.showAppLabels = showAppLabels
        self.taskbarColors = taskbarColors
        self.buttonColors = buttonColors
        self.showDisplayNumber = showDisplayNumber
        self.clock = clock
        self.buttonFont = buttonFont
        self.displayNumberFont = displayNumberFont
        self.clockFont = clockFont
    }
}

/// A user-configurable font for one taskbar element (buttons, the
/// display-number badge, or the clock). `family` is a font *family* name
/// (e.g. "Avenir Next"), not a PostScript name — see
/// `TaskbarTheme.resolvedFont(family:size:weight:)` for how it's resolved.
/// `nil`, empty, or an unrecognized family all fall back to the system font.
/// Each element's font weight (regular/bold/medium) is fixed and not
/// user-configurable — only family/size live here.
///
/// Note: `size` defaults to 11pt when omitted from a partial override,
/// regardless of which element this is — so overriding `displayNumberFont`
/// (whose real default is 10pt) with only `family` set yields 11pt, not 10pt.
public struct FontConfig: Codable, Equatable {
    public var family: String?
    public var size: Double

    public init(family: String? = nil, size: Double = 11) {
        self.family = family
        self.size = size
    }

    private enum CodingKeys: String, CodingKey {
        case family, size
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        family = try container.decodeIfPresent(String.self, forKey: .family)
        size = try container.decodeIfPresent(Double.self, forKey: .size) ?? 11
    }
}

/// A taskbar clock, formatted with a `DateFormatter`-style pattern (the same
/// Unicode date-field syntax `DateFormatter.dateFormat` uses — see the
/// README's Configuration section for a token reference and examples).
public struct ClockConfig: Codable, Equatable {
    public var enabled: Bool
    public var format: String

    public init(enabled: Bool = false, format: String = "h:mm a") {
        self.enabled = enabled
        self.format = format
    }

    private enum CodingKeys: String, CodingKey {
        case enabled, format
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        format = try container.decodeIfPresent(String.self, forKey: .format) ?? "h:mm a"
    }
}

/// Overrides applied on top of `taskbar`/`appearance` for every screen
/// except the one hosting the real Dock (see `TaskbarConfig.secondaryDisplay`).
public struct SecondaryDisplayConfig: Codable, Equatable {
    public var taskbar: TaskbarAppearanceOverrides
    public var appearance: AppearanceOverrides

    public init(
        taskbar: TaskbarAppearanceOverrides = TaskbarAppearanceOverrides(),
        appearance: AppearanceOverrides = AppearanceOverrides()
    ) {
        self.taskbar = taskbar
        self.appearance = appearance
    }

    private enum CodingKeys: String, CodingKey {
        case taskbar, appearance
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        taskbar = try container.decodeIfPresent(TaskbarAppearanceOverrides.self, forKey: .taskbar) ?? TaskbarAppearanceOverrides()
        appearance = try container.decodeIfPresent(AppearanceOverrides.self, forKey: .appearance) ?? AppearanceOverrides()
    }
}

/// Hex color overrides (e.g. `"#RRGGBB"` or `"#RRGGBBAA"`) for the taskbar's
/// own background/border. Leaving a field `null` (the default) means "follow
/// the system light/dark appearance" instead of a fixed color. There's no
/// `text` field here since the taskbar chrome itself (as opposed to its
/// buttons) only ever shows text via the display-number badge/clock, which
/// reuse `ButtonColorOverrides.text` for visual consistency with the rest of
/// the taskbar's text.
public struct TaskbarColorOverrides: Codable, Equatable {
    public var background: String?
    public var border: String?

    public init(background: String? = nil, border: String? = nil) {
        self.background = background
        self.border = border
    }
}

/// Hex color overrides for the taskbar buttons (pinned apps, running
/// windows, and the Quick Launch button), also reused for the display-number
/// badge and clock's text color. Every field is optional and `null` by
/// default, meaning "follow the system appearance/accent color".
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
