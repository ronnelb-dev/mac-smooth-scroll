import CoreGraphics
import XCTest
@testable import MacSmoothScroll

final class ScrollGestureLifecycleTests: XCTestCase {
    func testGesturePhasesProgressFromBeganToChangedToEnded() {
        var lifecycle = ScrollGestureLifecycle()
        lifecycle.prepareForBurst(flags: .maskCommand)

        XCTAssertEqual(
            lifecycle.phaseForOutput(trackpadSimulation: true),
            ScrollGestureEmission(phase: .began, flags: .maskCommand)
        )
        XCTAssertEqual(
            lifecycle.phaseForOutput(trackpadSimulation: true),
            ScrollGestureEmission(phase: .changed, flags: .maskCommand)
        )
        XCTAssertEqual(
            lifecycle.finish(),
            ScrollGestureEmission(phase: .ended, flags: .maskCommand)
        )
        XCTAssertFalse(lifecycle.isActive)
        XCTAssertEqual(lifecycle.outputFlags, [])
    }

    func testNativeOutputDoesNotStartAGesture() {
        var lifecycle = ScrollGestureLifecycle()
        lifecycle.prepareForBurst(flags: .maskShift)

        XCTAssertNil(
            lifecycle.phaseForOutput(trackpadSimulation: false)
        )
        XCTAssertFalse(lifecycle.isActive)
    }

    func testFinishingInactiveLifecycleStillClearsBurstFlags() {
        var lifecycle = ScrollGestureLifecycle()
        lifecycle.prepareForBurst(flags: .maskAlternate)

        XCTAssertNil(lifecycle.finish())
        XCTAssertFalse(lifecycle.isActive)
        XCTAssertEqual(lifecycle.outputFlags, [])
    }

    func testResetClearsActiveGestureAndBurstFlags() {
        var lifecycle = ScrollGestureLifecycle()
        lifecycle.prepareForBurst(flags: .maskControl)
        _ = lifecycle.phaseForOutput(trackpadSimulation: true)

        lifecycle.reset()

        XCTAssertFalse(lifecycle.isActive)
        XCTAssertEqual(lifecycle.outputFlags, [])
        XCTAssertNil(lifecycle.finish())
    }
}
