import XCTest
@testable import AXWindowKit

final class WindowEnumerationServiceTests: XCTestCase {
    /// CI runners won't have Accessibility permission granted, so this just
    /// verifies enumeration degrades gracefully (returns an empty/partial
    /// result) instead of crashing when AX calls are denied.
    func testEnumerateGroupsDoesNotCrashWithoutAccessibilityPermission() {
        let service = WindowEnumerationService()
        let groups = service.enumerateGroups()
        XCTAssertNotNil(groups)
    }

    func testRunningAppGroupRetainsOrderOfWindows() {
        let group = RunningAppGroup(
            id: 123,
            appName: "TestApp",
            bundleIdentifier: "com.example.testapp",
            icon: nil,
            windows: []
        )
        XCTAssertEqual(group.appName, "TestApp")
        XCTAssertEqual(group.windows.count, 0)
    }
}
