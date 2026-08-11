import XCTest
@testable import MacSmoothScroll

final class ScrollOutputSafetyTests: XCTestCase {
    func testOutputGateFailsClosedForTransformationUntilRestored() {
        var gate = ScrollOutputGate()

        XCTAssertTrue(gate.isAvailable)
        XCTAssertFalse(gate.record(false))
        XCTAssertFalse(gate.isAvailable)

        gate.restore()

        XCTAssertTrue(gate.isAvailable)
        XCTAssertTrue(gate.record(true))
        XCTAssertTrue(gate.isAvailable)
    }

    func testLegacyFrameCoalescerKeepsOnlyLatestPendingFrame() {
        var coalescer = DisplayFrameCoalescer()
        coalescer.beginSession()
        let first = DisplayFrameSample(timestamp: 1, fallbackDuration: 1.0 / 60.0)
        let latest = DisplayFrameSample(timestamp: 2, fallbackDuration: 1.0 / 60.0)

        let generation = coalescer.enqueue(first)
        XCTAssertNotNil(generation)
        XCTAssertNil(coalescer.enqueue(latest))
        XCTAssertEqual(coalescer.pendingFrame, latest)

        XCTAssertEqual(coalescer.takePending(for: generation!), latest)
        XCTAssertNil(coalescer.pendingFrame)
        XCTAssertFalse(coalescer.deliveryScheduled)
        XCTAssertNotNil(coalescer.enqueue(first))
    }

    func testLegacyFrameCoalescerRejectsStaleAndInactiveDeliveries() {
        var coalescer = DisplayFrameCoalescer()
        let frame = DisplayFrameSample(timestamp: 1, fallbackDuration: 1.0 / 60.0)

        XCTAssertNil(coalescer.enqueue(frame))
        coalescer.beginSession()
        let staleGeneration = coalescer.enqueue(frame)!
        coalescer.endSession()

        XCTAssertNil(coalescer.takePending(for: staleGeneration))
        XCTAssertNil(coalescer.pendingFrame)
        XCTAssertFalse(coalescer.deliveryScheduled)
    }
}
