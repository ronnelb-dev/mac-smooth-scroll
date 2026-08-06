import CoreGraphics
import XCTest
@testable import MacSmoothScroll

final class ScrollModifierResolverTests: XCTestCase {
    private let resolver = ScrollModifierResolver()

    func testZoomAloneSelectsZoomOutput() {
        let result = resolve(
            flags: .maskCommand,
            configuration: configuration()
        )

        XCTAssertEqual(result.speedAction, .standard)
        XCTAssertFalse(result.convertsToHorizontal)
        XCTAssertTrue(result.zoomActive)
    }

    func testPrecisionWinsWhenPrecisionAndFasterUseTheSameKey() {
        let result = resolve(
            flags: .maskAlternate,
            configuration: configuration(
                swiftModifier: .option,
                preciseModifier: .option
            )
        )

        XCTAssertEqual(result.speedAction, .precise)
    }

    func testPrecisionWinsWhenSeparatePrecisionAndFasterKeysAreHeld() {
        let result = resolve(
            flags: [.maskControl, .maskAlternate],
            configuration: configuration()
        )

        XCTAssertEqual(result.speedAction, .precise)
    }

    func testHorizontalAndPrecisionComposeWhenTheyUseTheSameKey() {
        let result = resolve(
            flags: .maskAlternate,
            configuration: configuration(
                horizontalModifier: .option,
                preciseModifier: .option
            )
        )

        XCTAssertTrue(result.convertsToHorizontal)
        XCTAssertEqual(result.speedAction, .precise)
    }

    func testHorizontalAndFasterComposeWhenTheyUseTheSameKey() {
        let result = resolve(
            flags: .maskControl,
            configuration: configuration(
                horizontalModifier: .control,
                swiftModifier: .control
            )
        )

        XCTAssertTrue(result.convertsToHorizontal)
        XCTAssertEqual(result.speedAction, .faster)
    }

    func testHorizontalConversionSuppressesZoom() {
        let result = resolve(
            flags: .maskCommand,
            configuration: configuration(
                horizontalModifier: .command,
                zoomModifier: .command
            )
        )

        XCTAssertTrue(result.convertsToHorizontal)
        XCTAssertFalse(result.zoomActive)
    }

    func testHorizontalAssignmentDoesNotSuppressZoomWhenConversionDoesNotApply() {
        let result = resolve(
            x: 20,
            y: 5,
            flags: .maskCommand,
            configuration: configuration(
                horizontalModifier: .command,
                zoomModifier: .command
            )
        )

        XCTAssertFalse(result.convertsToHorizontal)
        XCTAssertTrue(result.zoomActive)
    }

    func testPrecisionSuppressesZoomEvenWhenSeparateKeysAreHeld() {
        let result = resolve(
            flags: [.maskCommand, .maskAlternate],
            configuration: configuration()
        )

        XCTAssertEqual(result.speedAction, .precise)
        XCTAssertFalse(result.zoomActive)
    }

    func testFasterSuppressesZoomEvenWhenSeparateKeysAreHeld() {
        let result = resolve(
            flags: [.maskCommand, .maskControl],
            configuration: configuration()
        )

        XCTAssertEqual(result.speedAction, .faster)
        XCTAssertFalse(result.zoomActive)
    }

    func testNoneAssignmentsNeverActivate() {
        let result = resolve(
            flags: [.maskShift, .maskCommand, .maskControl, .maskAlternate],
            configuration: configuration(
                horizontalModifier: .none,
                zoomModifier: .none,
                swiftModifier: .none,
                preciseModifier: .none
            )
        )

        XCTAssertFalse(result.convertsToHorizontal)
        XCTAssertEqual(result.speedAction, .standard)
        XCTAssertFalse(result.zoomActive)
    }

    private func resolve(
        x: Double = 0,
        y: Double = 10,
        flags: CGEventFlags,
        configuration: ScrollTransformConfiguration
    ) -> ScrollModifierResolution {
        resolver.resolve(
            x: x,
            y: y,
            flags: flags,
            configuration: configuration
        )
    }

    private func configuration(
        horizontalModifier: ModifierKey = .shift,
        zoomModifier: ModifierKey = .command,
        swiftModifier: ModifierKey = .control,
        preciseModifier: ModifierKey = .option
    ) -> ScrollTransformConfiguration {
        ScrollTransformConfiguration(
            smoothness: .high,
            speed: .medium,
            minimumStepEnabled: true,
            minimumStepDistance: ScrollStep.defaultValue,
            minimumStepMultiplier: .standard,
            feel: .balanced,
            reverseDirection: false,
            adaptivePrecision: false,
            accelerationEnabled: true,
            axisLockEnabled: true,
            horizontalModifier: horizontalModifier,
            zoomModifier: zoomModifier,
            zoomBehavior: .pinch,
            swiftModifier: swiftModifier,
            preciseModifier: preciseModifier
        )
    }
}
