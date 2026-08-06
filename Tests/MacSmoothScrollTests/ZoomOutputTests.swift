import CoreGraphics
import XCTest
@testable import MacSmoothScroll

final class ZoomOutputTests: XCTestCase {
    func testPinchLifecycleBeginsChangesAndEndsWithoutTrackpadState() {
        var lifecycle = MagnificationLifecycle()
        lifecycle.prepareForBurst(isChromium: false)

        XCTAssertEqual(
            lifecycle.events(x: 0, y: 16),
            [
                MagnificationEventDescriptor(
                    magnification: 0.02,
                    phase: .began
                )
            ]
        )
        XCTAssertEqual(
            lifecycle.events(x: 0, y: -8),
            [
                MagnificationEventDescriptor(
                    magnification: -0.01,
                    phase: .changed
                )
            ]
        )
        XCTAssertEqual(
            lifecycle.finish(),
            MagnificationEventDescriptor(magnification: 0, phase: .ended)
        )
        XCTAssertFalse(lifecycle.isActive)
    }

    func testChromiumPinchAddsResponsiveFirstChange() {
        var lifecycle = MagnificationLifecycle()
        lifecycle.prepareForBurst(isChromium: true)

        let zoomIn = lifecycle.events(x: 0, y: 16)

        XCTAssertEqual(zoomIn.count, 2)
        XCTAssertEqual(zoomIn[0].phase, .began)
        XCTAssertEqual(zoomIn[0].magnification, 0.02, accuracy: 0.0001)
        XCTAssertEqual(zoomIn[1].phase, .changed)
        XCTAssertEqual(zoomIn[1].magnification, 0.495, accuracy: 0.0001)
    }

    func testChromiumPinchUsesDirectionalZoomOutBoost() {
        var lifecycle = MagnificationLifecycle()
        lifecycle.prepareForBurst(isChromium: true)

        let zoomOut = lifecycle.events(x: 0, y: -16)

        XCTAssertEqual(zoomOut.count, 2)
        XCTAssertEqual(zoomOut[1].magnification, -0.3325, accuracy: 0.0001)
    }

    func testFinishAndResetAreNoOpsWithoutActivePinch() {
        var lifecycle = MagnificationLifecycle()

        XCTAssertNil(lifecycle.finish())
        XCTAssertTrue(lifecycle.events(x: 0, y: 0).isEmpty)
        lifecycle.reset()
        XCTAssertFalse(lifecycle.isActive)
    }

    func testChromiumClassifierSupportsChromeChannelsAndRelatedBrowsers() {
        let classifier = ChromiumBundleClassifier()

        XCTAssertTrue(classifier.matches("com.google.Chrome"))
        XCTAssertTrue(classifier.matches("com.google.Chrome.canary"))
        XCTAssertTrue(classifier.matches("com.microsoft.edgemac"))
        XCTAssertTrue(classifier.matches("com.brave.Browser.beta"))
        XCTAssertFalse(classifier.matches("com.apple.Safari"))
        XCTAssertFalse(classifier.matches(nil))
    }

    func testPageZoomMapsDirectionsToStandardMacShortcuts() {
        var controller = PageZoomController()

        let zoomIn = controller.command(for: .zoomIn, at: 1)
        controller.reset()
        let zoomOut = controller.command(for: .zoomOut, at: 1)

        XCTAssertEqual(zoomIn?.keyCode, PageZoomController.zoomInKeyCode)
        XCTAssertEqual(zoomIn?.flags, [.maskCommand, .maskShift])
        XCTAssertEqual(zoomOut?.keyCode, PageZoomController.zoomOutKeyCode)
        XCTAssertEqual(zoomOut?.flags, .maskCommand)
    }

    func testPageZoomIsCappedAtTenCommandsPerSecond() {
        var controller = PageZoomController()

        XCTAssertNotNil(controller.command(for: .zoomIn, at: 1))
        XCTAssertNil(controller.command(for: .zoomIn, at: 1.05))
        XCTAssertNotNil(controller.command(for: .zoomIn, at: 1.11))
    }

    func testPageZoomResetAllowsImmediateCommand() {
        var controller = PageZoomController()
        XCTAssertNotNil(controller.command(for: .zoomIn, at: 1))

        controller.reset()

        XCTAssertNotNil(controller.command(for: .zoomOut, at: 1.01))
        XCTAssertNil(controller.command(for: nil, at: 2))
        XCTAssertNil(controller.command(for: .zoomIn, at: .nan))
    }
}
