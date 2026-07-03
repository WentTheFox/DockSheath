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

    func testDefaultsApplyForMissingOptionalFields() throws {
        let text = "{ \"schemaVersion\": 1 }"
        let config = try TaskbarConfig.parse(json5: text)
        XCTAssertEqual(config, TaskbarConfig(schemaVersion: 1))
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
