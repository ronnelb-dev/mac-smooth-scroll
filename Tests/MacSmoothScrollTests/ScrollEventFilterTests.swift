import XCTest
@testable import MacSmoothScroll

final class ScrollEventFilterTests: XCTestCase {
    private let filter = ScrollEventFilter()

    func testDiscreteExternalWheelEventIsTransformed() {
        XCTAssertEqual(
            filter.disposition(sourceUserData: 0, isContinuous: false),
            .transform
        )
    }

    func testContinuousTrackpadOrMagicMouseEventPassesThrough() {
        XCTAssertEqual(
            filter.disposition(sourceUserData: 0, isContinuous: true),
            .passThrough
        )
    }

    func testSyntheticOutputIsNotProcessedAgain() {
        XCTAssertEqual(
            filter.disposition(
                sourceUserData: ScrollEventFilter.syntheticMarker,
                isContinuous: false
            ),
            .passThrough
        )
    }
}
