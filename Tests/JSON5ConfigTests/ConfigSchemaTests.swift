import XCTest
@testable import JSON5Config

final class ConfigSchemaTests: XCTestCase {
    func testParsesFullDocumentWithCommentsAndTrailingCommas() throws {
        let text = """
        {
          // DockSheath config
          "schemaVersion": 1,
          "pinnedApps": [
            { "bundlePath": "/Applications/Safari.app", "bundleIdentifier": "com.apple.Safari" },
          ],
          "taskbar": { "sizeOverride": null, },
          "hotkeys": { "toggleVisibility": { "keyCode": 2, "modifiers": ["command", "option"] } },
          "behavior": {
            "autoHideOnMouseLeave": false,
            "showOnAllDisplays": false,
            "groupWindowsByApp": true,
            "refreshIntervalMs": 1500,
          },
          "appearance": { "theme": "auto", "iconSize": 32, "showAppLabels": false },
        }
        """

        let config = try TaskbarConfig.parse(json5: text)
        XCTAssertEqual(config.schemaVersion, 1)
        XCTAssertEqual(config.pinnedApps.count, 1)
        XCTAssertEqual(config.pinnedApps.first?.bundleIdentifier, "com.apple.Safari")
        XCTAssertNil(config.taskbar.sizeOverride)
        XCTAssertEqual(config.hotkeys.toggleVisibility?.keyCode, 2)
        XCTAssertTrue(config.behavior.groupWindowsByApp)
        XCTAssertEqual(config.appearance.theme, "auto")
    }

    func testParsesFullJSON5SyntaxThroughToTypedConfig() throws {
        let text = """
        {
          // full JSON5 syntax exercised end-to-end
          schemaVersion: 1,
          pinnedApps: [
            { bundlePath: '/Applications/Safari.app', bundleIdentifier: 'com.apple.Safari' },
          ],
          taskbar: { sizeOverride: .5e2 }, // unquoted key + leading-dot exponent number
          appearance: { theme: 'auto', iconSize: 0x20, showAppLabels: false },
        }
        """

        let config = try TaskbarConfig.parse(json5: text)
        XCTAssertEqual(config.schemaVersion, 1)
        XCTAssertEqual(config.pinnedApps.first?.bundlePath, "/Applications/Safari.app")
        XCTAssertEqual(config.taskbar.sizeOverride, 50)
        XCTAssertEqual(config.appearance.iconSize, 32)
    }

    func testParsesTaskbarAndButtonColorOverrides() throws {
        let text = """
        {
          appearance: {
            accentColor: '#FF6600',
            taskbarColors: { background: '#1E1E1EDD', border: null },
            buttonColors: { background: null, border: '#333333', text: '#FFFFFF' },
          },
        }
        """

        let config = try TaskbarConfig.parse(json5: text)
        XCTAssertEqual(config.appearance.accentColor, "#FF6600")
        XCTAssertEqual(config.appearance.taskbarColors.background, "#1E1E1EDD")
        XCTAssertNil(config.appearance.taskbarColors.border)
        XCTAssertNil(config.appearance.buttonColors.background)
        XCTAssertEqual(config.appearance.buttonColors.border, "#333333")
        XCTAssertEqual(config.appearance.buttonColors.text, "#FFFFFF")
    }

    func testDefaultsApplyForMissingOptionalFields() throws {
        let text = "{ \"schemaVersion\": 1 }"
        let config = try TaskbarConfig.parse(json5: text)
        XCTAssertEqual(config, TaskbarConfig(schemaVersion: 1))
    }

    func testParsesDisplayNumberAndClockConfig() throws {
        let text = """
        {
          appearance: {
            showDisplayNumber: true,
            clock: { enabled: true, format: 'HH:mm' },
          },
        }
        """

        let config = try TaskbarConfig.parse(json5: text)
        XCTAssertTrue(config.appearance.showDisplayNumber)
        XCTAssertTrue(config.appearance.clock.enabled)
        XCTAssertEqual(config.appearance.clock.format, "HH:mm")
    }

    func testClockConfigDefaultsWhenFieldsMissing() throws {
        let text = "{ appearance: { clock: {} } }"
        let config = try TaskbarConfig.parse(json5: text)
        XCTAssertFalse(config.appearance.clock.enabled)
        XCTAssertEqual(config.appearance.clock.format, "h:mm a")
    }

    func testParsesFontConfig() throws {
        let text = """
        {
          appearance: {
            buttonFont: { family: 'Menlo', size: 13 },
            displayNumberFont: { family: 'Avenir Next', size: 9 },
            clockFont: { family: null, size: 14 },
          },
        }
        """

        let config = try TaskbarConfig.parse(json5: text)
        XCTAssertEqual(config.appearance.buttonFont.family, "Menlo")
        XCTAssertEqual(config.appearance.buttonFont.size, 13)
        XCTAssertEqual(config.appearance.displayNumberFont.family, "Avenir Next")
        XCTAssertEqual(config.appearance.displayNumberFont.size, 9)
        XCTAssertNil(config.appearance.clockFont.family)
        XCTAssertEqual(config.appearance.clockFont.size, 14)
    }

    func testFontConfigDefaultsWhenMissing() throws {
        let text = "{ appearance: {} }"
        let config = try TaskbarConfig.parse(json5: text)
        XCTAssertNil(config.appearance.buttonFont.family)
        XCTAssertEqual(config.appearance.buttonFont.size, 11)
        XCTAssertNil(config.appearance.displayNumberFont.family)
        XCTAssertEqual(config.appearance.displayNumberFont.size, 10)
        XCTAssertNil(config.appearance.clockFont.family)
        XCTAssertEqual(config.appearance.clockFont.size, 11)
    }

    func testFontConfigPartialOverrideFallsBackToElevenPoint() throws {
        let text = """
        {
          appearance: {
            displayNumberFont: { family: 'Menlo' },
          },
        }
        """

        let config = try TaskbarConfig.parse(json5: text)
        XCTAssertEqual(config.appearance.displayNumberFont.family, "Menlo")
        // displayNumberFont's true default is 10pt, but a partial override
        // that omits `size` falls back to FontConfig's own baseline (11pt) —
        // a documented, intentional wrinkle (see FontConfig's doc comment).
        XCTAssertEqual(config.appearance.displayNumberFont.size, 11)
    }

    func testSecondaryDisplayFontOverrides() throws {
        let text = """
        {
          appearance: {
            buttonFont: { family: 'Menlo', size: 12 },
            displayNumberFont: { family: 'Menlo', size: 10 },
          },
          secondaryDisplay: {
            appearance: {
              clockFont: { family: 'Avenir Next', size: 16 },
            },
          },
        }
        """

        let config = try TaskbarConfig.parse(json5: text)
        let effectiveAppearance = config.appearance.applying(config.secondaryDisplay.appearance)

        XCTAssertEqual(effectiveAppearance.clockFont.family, "Avenir Next")
        XCTAssertEqual(effectiveAppearance.clockFont.size, 16)
        // Fields left unset in the override inherit the main config's value.
        XCTAssertEqual(effectiveAppearance.buttonFont.family, "Menlo")
        XCTAssertEqual(effectiveAppearance.buttonFont.size, 12)
        XCTAssertEqual(effectiveAppearance.displayNumberFont.family, "Menlo")
        XCTAssertEqual(effectiveAppearance.displayNumberFont.size, 10)
    }

    func testSecondaryDisplayConfigDefaultsWhenMissing() throws {
        let text = "{ \"schemaVersion\": 1 }"
        let config = try TaskbarConfig.parse(json5: text)
        XCTAssertEqual(config.secondaryDisplay, SecondaryDisplayConfig())
        XCTAssertNil(config.secondaryDisplay.taskbar.sizeOverride)
        XCTAssertNil(config.secondaryDisplay.appearance.theme)
    }

    func testSecondaryDisplayOverridesOnlySpecifiedFields() throws {
        let text = """
        {
          taskbar: { sizeOverride: 32 },
          appearance: { theme: 'auto', iconSize: 32, showDisplayNumber: false },
          secondaryDisplay: {
            taskbar: { sizeOverride: 40 },
            appearance: { theme: 'dark', showDisplayNumber: true },
          },
        }
        """

        let config = try TaskbarConfig.parse(json5: text)
        let effectiveTaskbar = config.taskbar.applying(config.secondaryDisplay.taskbar)
        let effectiveAppearance = config.appearance.applying(config.secondaryDisplay.appearance)

        XCTAssertEqual(effectiveTaskbar.sizeOverride, 40)
        XCTAssertEqual(effectiveAppearance.theme, "dark")
        XCTAssertTrue(effectiveAppearance.showDisplayNumber)
        // Fields left unset in the override inherit the main config's value.
        XCTAssertEqual(effectiveAppearance.iconSize, 32)
    }

    func testMalformedJSONThrowsDecodingFailed() {
        let text = "{ this is not valid json5 at all"
        XCTAssertThrowsError(try TaskbarConfig.parse(json5: text)) { error in
            guard case TaskbarConfig.ParseError.decodingFailed = error else {
                return XCTFail("Expected decodingFailed, got \(error)")
            }
        }
    }
}
