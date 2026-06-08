import XCTest
@testable import CommandGatheringApp

final class CommandListSplitLayoutTests: XCTestCase {
    func testDefaultHeightIsTallerThanTwoCompactRows() {
        let twoRowsHeight = (Theme.compactCardHeight * 2) + 16 + 8
        XCTAssertGreaterThan(CommandListSplitLayout.defaultTopHeight, twoRowsHeight)
    }

    func testStorageKeyUsesNewVersionToIgnoreOldPinnedHeight() {
        XCTAssertEqual(CommandListSplitLayout.storageKey, "commandListHeight.relaxedV1")
    }

    func testConstrainedTopHeightAllowsGrowingBeyondLegacyTwoRowLimit() {
        let constrained = CommandListSplitLayout.constrainedTopHeight(320, totalHeight: 720)
        XCTAssertEqual(constrained, 320)
    }

    func testConstrainedTopHeightStillProtectsBottomPane() {
        let constrained = CommandListSplitLayout.constrainedTopHeight(600, totalHeight: 720)
        XCTAssertEqual(constrained, 460)
    }
}
