import CoreGraphics
import XCTest
@testable import MacSmoothScroll

final class ScrollInputTransformerTests: XCTestCase {
    func testLineDeltaFallsBackToEighteenPointSteps() {
        var transformer = ScrollInputTransformer()
        let impulse = transformer.transform(
            sample(lineY: 2),
            using: configuration()
        )

        XCTAssertEqual(impulse.x, 0, accuracy: 0.0001)
        XCTAssertEqual(impulse.y, 2.52, accuracy: 0.0001)
    }

    func testPointDeltaTakesPriorityOverLineDelta() {
        var transformer = ScrollInputTransformer()
        let impulse = transformer.transform(
            sample(lineY: 10, pointY: 5),
            using: configuration()
        )

        XCTAssertEqual(impulse.y, 0.35, accuracy: 0.0001)
    }

    func testHorizontalModifierMovesVerticalInputToHorizontalAxis() {
        var transformer = ScrollInputTransformer()
        let impulse = transformer.transform(
            sample(pointY: 10, flags: .maskShift),
            using: configuration()
        )

        XCTAssertEqual(impulse.x, 0.7, accuracy: 0.0001)
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
        )

        XCTAssertEqual(impulse.y, -2.9, accuracy: 0.0001)
    }

    func testSwiftAndPreciseModifiersCompose() {
        var transformer = ScrollInputTransformer()
        let impulse = transformer.transform(
            sample(
                pointY: 10,
                flags: [.maskControl, .maskAlternate]
            ),
            using: configuration()
        )

        XCTAssertEqual(impulse.y, 0.4704, accuracy: 0.0001)
    }

    func testAdaptivePrecisionUsesTimeBetweenPhysicalEvents() {
        var transformer = ScrollInputTransformer()
        let config = configuration(smoothness: .low)

        let first = transformer.transform(
            sample(pointY: 10, timestamp: 1.0),
            using: config
        )
        let isolated = transformer.transform(
            sample(pointY: 10, timestamp: 1.2),
            using: config
        )
        let slower = transformer.transform(
            sample(pointY: 10, timestamp: 1.32),
            using: config
        )
        let rapid = transformer.transform(
            sample(pointY: 10, timestamp: 1.37),
            using: config
        )

        XCTAssertEqual(first.y, 2.0, accuracy: 0.0001)
        XCTAssertEqual(isolated.y, 0.56, accuracy: 0.0001)
        XCTAssertEqual(slower.y, 1.04, accuracy: 0.0001)
        XCTAssertEqual(rapid.y, 2.0, accuracy: 0.0001)
    }

    func testResetClearsAdaptivePrecisionHistory() {
        var transformer = ScrollInputTransformer()
        let config = configuration(smoothness: .low)

        _ = transformer.transform(
            sample(pointY: 10, timestamp: 1.0),
            using: config
        )
        transformer.reset()
        let impulse = transformer.transform(
            sample(pointY: 10, timestamp: 2.0),
            using: config
        )

        XCTAssertEqual(impulse.y, 2.0, accuracy: 0.0001)
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
        reverseDirection: Bool = false,
        adaptivePrecision: Bool = true,
        horizontalModifier: ModifierKey = .shift,
        swiftModifier: ModifierKey = .control,
        preciseModifier: ModifierKey = .option
    ) -> ScrollTransformConfiguration {
        ScrollTransformConfiguration(
            smoothness: smoothness,
            speed: speed,
            reverseDirection: reverseDirection,
            adaptivePrecision: adaptivePrecision,
            horizontalModifier: horizontalModifier,
            swiftModifier: swiftModifier,
            preciseModifier: preciseModifier
        )
    }
}
