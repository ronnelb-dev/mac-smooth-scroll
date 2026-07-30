import CoreGraphics
import XCTest
@testable import MacSmoothScroll

final class ScrollInputTransformerTests: XCTestCase {
    func testLineDeltaFallsBackToEighteenPointSteps() {
        var transformer = ScrollInputTransformer()
        let result = transformer.transform(
            sample(lineY: 2),
            using: configuration()
        )

        let impulse = result.impulse
        XCTAssertEqual(impulse.x, 0, accuracy: 0.0001)
        XCTAssertEqual(impulse.y, 2.52, accuracy: 0.0001)
    }

    func testPointDeltaTakesPriorityOverLineDelta() {
        var transformer = ScrollInputTransformer()
        let impulse = transformer.transform(
            sample(lineY: 10, pointY: 5),
            using: configuration()
        ).impulse

        XCTAssertEqual(impulse.y, 1.26, accuracy: 0.0001)
    }

    func testHorizontalModifierMovesVerticalInputToHorizontalAxis() {
        var transformer = ScrollInputTransformer()
        let impulse = transformer.transform(
            sample(pointY: 10, flags: .maskShift),
            using: configuration()
        ).impulse

        XCTAssertEqual(impulse.x, 1.26, accuracy: 0.0001)
        XCTAssertEqual(impulse.y, 0, accuracy: 0.0001)
    }

    func testReverseDirectionAndFastSpeedAreApplied() {
        var transformer = ScrollInputTransformer()
        let impulse = transformer.transform(
            sample(pointY: 10),
            using: configuration(
                smoothness: .low,
                speed: .fast,
                reverseDirection: true
            )
        ).impulse

        XCTAssertEqual(impulse.y, -3.6, accuracy: 0.0001)
    }

    func testPreciseModifierTakesPriorityOverSwiftModifier() {
        var transformer = ScrollInputTransformer()
        let impulse = transformer.transform(
            sample(
                pointY: 10,
                flags: [.maskControl, .maskAlternate]
            ),
            using: configuration()
        ).impulse

        XCTAssertEqual(impulse.y, 0.3528, accuracy: 0.0001)
    }

    func testAdaptivePrecisionUsesTimeBetweenPhysicalEvents() {
        var transformer = ScrollInputTransformer()
        let config = configuration(smoothness: .low, adaptivePrecision: true)

        let first = transformer.transform(
            sample(pointY: 100, timestamp: 1.0),
            using: config
        ).impulse
        let isolated = transformer.transform(
            sample(pointY: 100, timestamp: 1.2),
            using: config
        ).impulse
        let slower = transformer.transform(
            sample(pointY: 100, timestamp: 1.32),
            using: config
        ).impulse
        let rapid = transformer.transform(
            sample(pointY: 100, timestamp: 1.37),
            using: config
        ).impulse

        XCTAssertEqual(first.y, 6, accuracy: 0.0001)
        XCTAssertEqual(isolated.y, 6, accuracy: 0.0001)
        XCTAssertEqual(slower.y, 13, accuracy: 0.0001)
        XCTAssertEqual(rapid.y, 21.232, accuracy: 0.0001)
    }

    func testResetClearsAdaptivePrecisionHistory() {
        var transformer = ScrollInputTransformer()
        let config = configuration(smoothness: .low, adaptivePrecision: true)

        _ = transformer.transform(
            sample(pointY: 100, timestamp: 1.0),
            using: config
        )
        transformer.reset()
        let impulse = transformer.transform(
            sample(pointY: 100, timestamp: 2.0),
            using: config
        ).impulse

        XCTAssertEqual(impulse.y, 6, accuracy: 0.0001)
    }

    func testFirstNotchAfterIdleBeginsPreciseNewBurst() {
        var transformer = ScrollInputTransformer()
        let config = configuration(smoothness: .low, adaptivePrecision: true)

        let first = transformer.transform(
            sample(pointY: 100, flags: .maskCommand, timestamp: 1),
            using: config
        )
        let afterIdle = transformer.transform(
            sample(pointY: 100, timestamp: 2),
            using: config
        )

        XCTAssertTrue(first.beginsNewBurst)
        XCTAssertEqual(first.impulse.y, 6, accuracy: 0.0001)
        XCTAssertTrue(afterIdle.beginsNewBurst)
        XCTAssertEqual(afterIdle.impulse.y, 6, accuracy: 0.0001)
    }

    func testModifierFlagsAreFrozenForBurst() {
        var transformer = ScrollInputTransformer()
        let config = configuration()

        let first = transformer.transform(
            sample(pointY: 10, flags: .maskCommand, timestamp: 1),
            using: config
        )
        let continued = transformer.transform(
            sample(pointY: 10, timestamp: 1.05),
            using: config
        )

        XCTAssertEqual(first.outputFlags, .maskCommand)
        XCTAssertEqual(continued.outputFlags, .maskCommand)
        XCTAssertFalse(continued.beginsNewBurst)
    }

    func testOnlyConfiguredZoomModifierIsForwarded() {
        var transformer = ScrollInputTransformer()
        let config = configuration(zoomModifier: .command)

        let unassigned = transformer.transform(
            sample(pointY: 10, flags: .maskAlternate, timestamp: 1),
            using: config
        )
        let zoom = transformer.transform(
            sample(pointY: 10, flags: .maskCommand, timestamp: 2),
            using: config
        )

        XCTAssertEqual(unassigned.outputFlags, [])
        XCTAssertEqual(zoom.outputFlags, .maskCommand)
    }

    func testTransformActionTakesPriorityOverZoomConflict() {
        var transformer = ScrollInputTransformer()
        let config = configuration(
            horizontalModifier: .command,
            zoomModifier: .command
        )

        let result = transformer.transform(
            sample(pointY: 10, flags: .maskCommand),
            using: config
        )

        XCTAssertNotEqual(result.impulse.x, 0)
        XCTAssertEqual(result.impulse.y, 0)
        XCTAssertEqual(result.outputFlags, [])
    }

    func testDominantAxisLockSuppressesCrossAxisNoiseForBurst() {
        var transformer = ScrollInputTransformer()
        let config = configuration()

        let first = transformer.transform(
            sample(pointX: 2, pointY: 10, timestamp: 1),
            using: config
        )
        let continued = transformer.transform(
            sample(pointX: 8, pointY: 3, timestamp: 1.05),
            using: config
        )

        XCTAssertEqual(first.impulse.x, 0, accuracy: 0.0001)
        XCTAssertEqual(continued.impulse.x, 0, accuracy: 0.0001)
        XCTAssertNotEqual(continued.impulse.y, 0)
    }

    func testStepRaisesSmallDeltasAndPreservesSigns() {
        var transformer = ScrollInputTransformer()
        let config = configuration(
            minimumStepDistance: 20,
            horizontalModifier: .none
        )

        let result = transformer.transform(
            sample(pointX: -6, pointY: 7),
            using: config
        )

        XCTAssertEqual(result.impulse.x, -1.4, accuracy: 0.0001)
        XCTAssertEqual(result.impulse.y, 1.4, accuracy: 0.0001)
    }

    func testDisabledStepDoesNotRaiseSmallDeltas() {
        var transformer = ScrollInputTransformer()
        let result = transformer.transform(
            sample(pointY: 10),
            using: configuration(
                smoothness: .low,
                speed: .slow,
                minimumStepEnabled: false,
                minimumStepDistance: 100,
                adaptivePrecision: true
            )
        )

        XCTAssertEqual(result.impulse.y, 0.432, accuracy: 0.0001)
    }

    func testStepLeavesLargeAndZeroDeltasUnchanged() {
        var transformer = ScrollInputTransformer()
        let result = transformer.transform(
            sample(pointX: 0, pointY: 40),
            using: configuration(minimumStepDistance: 18)
        )

        XCTAssertEqual(result.impulse.x, 0, accuracy: 0.0001)
        XCTAssertEqual(result.impulse.y, 2.8, accuracy: 0.0001)
    }

    func testStepIsAppliedAfterSpeedAndAdaptivePrecision() {
        var transformer = ScrollInputTransformer()
        let result = transformer.transform(
            sample(pointY: 40),
            using: configuration(
                smoothness: .low,
                speed: .slow,
                minimumStepDistance: 20,
                adaptivePrecision: true
            )
        )

        XCTAssertEqual(result.impulse.y, 4, accuracy: 0.0001)
    }

    func testPrecisionModifierIntentionallyOverridesFinalStep() {
        var transformer = ScrollInputTransformer()
        let result = transformer.transform(
            sample(pointY: 10, flags: .maskAlternate),
            using: configuration(
                smoothness: .low,
                minimumStepDistance: 20
            )
        )

        XCTAssertEqual(result.impulse.y, 1.12, accuracy: 0.0001)
    }

    func testDominantAxisLockRunsBeforeMinimumStep() {
        var transformer = ScrollInputTransformer()
        let result = transformer.transform(
            sample(pointX: 2, pointY: 10),
            using: configuration(minimumStepDistance: 18)
        )

        XCTAssertEqual(result.impulse.x, 0, accuracy: 0.0001)
        XCTAssertEqual(result.impulse.y, 1.26, accuracy: 0.0001)
    }

    func testModifierMetadataAndFlags() {
        XCTAssertEqual(ModifierKey.shift.title, "Shift")
        XCTAssertEqual(ModifierKey.command.symbol, "⌘")
        XCTAssertTrue(ModifierKey.option.isActive(in: .maskAlternate))
        XCTAssertFalse(ModifierKey.none.isActive(in: .maskShift))
    }

    private func sample(
        lineX: Double = 0,
        lineY: Double = 0,
        pointX: Double = 0,
        pointY: Double = 0,
        flags: CGEventFlags = [],
        timestamp: TimeInterval = 1
    ) -> ScrollInputSample {
        ScrollInputSample(
            lineX: lineX,
            lineY: lineY,
            pointX: pointX,
            pointY: pointY,
            flags: flags,
            timestamp: timestamp
        )
    }

    private func configuration(
        smoothness: Smoothness = .high,
        speed: ScrollSpeed = .medium,
        minimumStepEnabled: Bool = true,
        minimumStepDistance: Double = ScrollStep.defaultValue,
        feel: ScrollFeel = .balanced,
        reverseDirection: Bool = false,
        adaptivePrecision: Bool = false,
        horizontalModifier: ModifierKey = .shift,
        zoomModifier: ModifierKey = .command,
        swiftModifier: ModifierKey = .control,
        preciseModifier: ModifierKey = .option
    ) -> ScrollTransformConfiguration {
        ScrollTransformConfiguration(
            smoothness: smoothness,
            speed: speed,
            minimumStepEnabled: minimumStepEnabled,
            minimumStepDistance: minimumStepDistance,
            feel: feel,
            reverseDirection: reverseDirection,
            adaptivePrecision: adaptivePrecision,
            horizontalModifier: horizontalModifier,
            zoomModifier: zoomModifier,
            swiftModifier: swiftModifier,
            preciseModifier: preciseModifier
        )
    }
}
