import XCTest
@testable import AXWindowKit

final class AXGeometryTests: XCTestCase {
    func testFlipsTopLeftOriginToBottomLeftOrigin() {
        // A 1000pt-tall primary screen; an AX-space window at the very top
        // (y=0) should land at Cocoa y = 1000 - 0 - 100 = 900.
        let axRect = CGRect(x: 50, y: 0, width: 200, height: 100)
        let cocoaRect = AXGeometry.flip(axRect, primaryScreenHeight: 1000)
        XCTAssertEqual(cocoaRect, CGRect(x: 50, y: 900, width: 200, height: 100))
    }

    func testFlipIsItsOwnInverse() {
        let original = CGRect(x: 10, y: 20, width: 300, height: 150)
        let roundTripped = AXGeometry.flip(AXGeometry.flip(original, primaryScreenHeight: 1200), primaryScreenHeight: 1200)
        XCTAssertEqual(roundTripped, original)
    }

    func testWindowFlushWithBottomOfPrimaryScreenMapsToBottomInCocoaSpace() {
        // AX-space window whose bottom edge touches the screen's bottom
        // (y + height == primaryScreenHeight) should map to Cocoa y = 0.
        let axRect = CGRect(x: 0, y: 800, width: 400, height: 200)
        let cocoaRect = AXGeometry.flip(axRect, primaryScreenHeight: 1000)
        XCTAssertEqual(cocoaRect.origin.y, 0)
    }
}
