import XCTest
@testable import AXWindowKit

final class WindowFrameAdjusterTests: XCTestCase {
    let screenFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)

    func testNoAdjustmentWhenWindowDoesNotOverlapReservedRect() {
        let reservedRect = CGRect(x: 0, y: 0, width: 1920, height: 70) // bottom strip
        let windowFrame = CGRect(x: 100, y: 200, width: 800, height: 600)
        XCTAssertNil(WindowFrameAdjuster.adjustedFrame(for: windowFrame, avoiding: reservedRect, on: screenFrame))
    }

    func testPullsWindowAboveBottomReservedStrip() {
        let reservedRect = CGRect(x: 0, y: 0, width: 1920, height: 70)
        let windowFrame = CGRect(x: 100, y: 0, width: 800, height: 600)

        let adjusted = WindowFrameAdjuster.adjustedFrame(for: windowFrame, avoiding: reservedRect, on: screenFrame)

        XCTAssertEqual(adjusted?.origin.y, 70)
        XCTAssertEqual(adjusted?.maxY, windowFrame.maxY, "top edge should stay fixed")
        XCTAssertEqual(adjusted?.height, 530)
    }

    func testPullsWindowRightOfLeftReservedStrip() {
        let reservedRect = CGRect(x: 0, y: 0, width: 70, height: 1080)
        let windowFrame = CGRect(x: 0, y: 100, width: 600, height: 400)

        let adjusted = WindowFrameAdjuster.adjustedFrame(for: windowFrame, avoiding: reservedRect, on: screenFrame)

        XCTAssertEqual(adjusted?.origin.x, 70)
        XCTAssertEqual(adjusted?.maxX, windowFrame.maxX, "right edge should stay fixed")
        XCTAssertEqual(adjusted?.width, 530)
    }

    func testPullsWindowLeftOfRightReservedStrip() {
        let reservedRect = CGRect(x: 1850, y: 0, width: 70, height: 1080)
        let windowFrame = CGRect(x: 1600, y: 100, width: 400, height: 400)

        let adjusted = WindowFrameAdjuster.adjustedFrame(for: windowFrame, avoiding: reservedRect, on: screenFrame)

        XCTAssertEqual(adjusted?.origin.x, windowFrame.origin.x, "left edge should stay fixed")
        XCTAssertEqual(adjusted?.maxX, 1850)
        XCTAssertEqual(adjusted?.width, 250)
    }

    func testClampsToZeroRatherThanNegativeSizeInDegenerateOverlap() {
        let reservedRect = CGRect(x: 0, y: 0, width: 1920, height: 1080) // whole screen, pathological
        let windowFrame = CGRect(x: 100, y: 0, width: 800, height: 200)

        let adjusted = WindowFrameAdjuster.adjustedFrame(for: windowFrame, avoiding: reservedRect, on: screenFrame)

        XCTAssertEqual(adjusted?.height, 0)
    }
}
