import CoreGraphics
import XCTest
@testable import MacSmoothScroll

final class ScrollModifierResolverTests: XCTestCase {
    private let resolver = ScrollModifierResolver()

    func testZoomAloneIsForwardedToTheTargetApplication() {
        let result = resolve(
            flags: .maskCommand,
            configuration: configuration()
        )

        XCTAssertEqual(result.speedAction, .standard)
        XCTAssertFalse(result.convertsToHorizontal)
        XCTAssertEqual(result.forwardedFlags, .maskCommand)
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
        XCTAssertEqual(result.forwardedFlags, [])
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
        XCTAssertEqual(result.forwardedFlags, .maskCommand)
    }

    func testPrecisionSuppressesZoomEvenWhenSeparateKeysAreHeld() {
        let result = resolve(
            flags: [.maskCommand, .maskAlternate],
            configuration: configuration()
        )

        XCTAssertEqual(result.speedAction, .precise)
        XCTAssertEqual(result.forwardedFlags, [])
    }

    func testFasterSuppressesZoomEvenWhenSeparateKeysAreHeld() {
        let result = resolve(
            flags: [.maskCommand, .maskControl],
            configuration: configuration()
        )

        XCTAssertEqual(result.speedAction, .faster)
        XCTAssertEqual(result.forwardedFlags, [])
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
        XCTAssertEqual(result.forwardedFlags, [])
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
            feel: .balanced,
            reverseDirection: false,
            adaptivePrecision: false,
            horizontalModifier: horizontalModifier,
            zoomModifier: zoomModifier,
            swiftModifier: swiftModifier,
            preciseModifier: preciseModifier
        )
    }
}
