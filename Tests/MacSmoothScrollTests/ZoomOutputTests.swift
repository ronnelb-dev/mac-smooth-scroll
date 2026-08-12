import Carbon.HIToolbox
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

        XCTAssertEqual(zoomIn?.keyCode, PageZoomShortcutSet.fallback.zoomIn.keyCode)
        XCTAssertEqual(zoomIn?.flags, [.maskCommand, .maskShift])
        XCTAssertEqual(zoomIn?.characters, "+")
        XCTAssertEqual(zoomOut?.keyCode, PageZoomShortcutSet.fallback.zoomOut.keyCode)
        XCTAssertEqual(zoomOut?.flags, .maskCommand)
        XCTAssertEqual(zoomOut?.characters, "-")
    }

    func testPageZoomSynthesizesOnlyMissingModifierTransitions() {
        let command = PageZoomCommandDescriptor(
            direction: .zoomIn,
            keyCode: CGKeyCode(kVK_ANSI_Equal),
            flags: [.maskCommand, .maskShift],
            characters: "+"
        )

        let events = PageZoomKeyEventSequence().events(
            for: command,
            physicalFlags: .maskCommand
        )

        XCTAssertEqual(
            events,
            [
                PageZoomKeyEventDescriptor(
                    keyCode: CGKeyCode(kVK_Shift),
                    keyDown: true,
                    flags: [.maskCommand, .maskShift]
                ),
                PageZoomKeyEventDescriptor(
                    keyCode: CGKeyCode(kVK_ANSI_Equal),
                    keyDown: true,
                    flags: [.maskCommand, .maskShift]
                ),
                PageZoomKeyEventDescriptor(
                    keyCode: CGKeyCode(kVK_ANSI_Equal),
                    keyDown: false,
                    flags: [.maskCommand, .maskShift]
                ),
                PageZoomKeyEventDescriptor(
                    keyCode: CGKeyCode(kVK_Shift),
                    keyDown: false,
                    flags: .maskCommand
                )
            ]
        )
    }

    func testPageZoomDoesNotReleasePhysicallyHeldCommand() {
        let command = PageZoomCommandDescriptor(
            direction: .zoomOut,
            keyCode: CGKeyCode(kVK_ANSI_Minus),
            flags: .maskCommand,
            characters: "-"
        )

        let events = PageZoomKeyEventSequence().events(
            for: command,
            physicalFlags: .maskCommand
        )

        XCTAssertEqual(
            events,
            [
                PageZoomKeyEventDescriptor(
                    keyCode: CGKeyCode(kVK_ANSI_Minus),
                    keyDown: true,
                    flags: .maskCommand
                ),
                PageZoomKeyEventDescriptor(
                    keyCode: CGKeyCode(kVK_ANSI_Minus),
                    keyDown: false,
                    flags: .maskCommand
                )
            ]
        )
        XCTAssertFalse(events.contains { $0.keyCode == CGKeyCode(kVK_Command) })
    }

    func testPageZoomSynthesizesCommandForNonCommandActivationModifier() {
        let command = PageZoomCommandDescriptor(
            direction: .zoomOut,
            keyCode: CGKeyCode(kVK_ANSI_Minus),
            flags: .maskCommand,
            characters: "-"
        )

        let events = PageZoomKeyEventSequence().events(
            for: command,
            physicalFlags: .maskAlternate
        )

        XCTAssertEqual(events.first?.keyCode, CGKeyCode(kVK_Command))
        XCTAssertEqual(events.first?.keyDown, true)
        XCTAssertEqual(events.last?.keyCode, CGKeyCode(kVK_Command))
        XCTAssertEqual(events.last?.keyDown, false)
        XCTAssertFalse(events.contains { $0.flags.contains(.maskAlternate) })
    }

    func testPageZoomResolvesCurrentLayoutCandidates() {
        let resolver = PageZoomShortcutResolver()
        let shortcuts = resolver.resolve(candidates: [
            KeyboardLayoutKeyCandidate(
                keyCode: 42,
                flags: .maskAlternate,
                characters: "+"
            ),
            KeyboardLayoutKeyCandidate(
                keyCode: 43,
                flags: [.maskShift, .maskAlternate],
                characters: "-"
            )
        ])
        var controller = PageZoomController()
        let zoomIn = controller.command(
            for: .zoomIn,
            at: 1,
            shortcuts: shortcuts
        )
        controller.reset()
        let zoomOut = controller.command(
            for: .zoomOut,
            at: 1,
            shortcuts: shortcuts
        )

        XCTAssertEqual(zoomIn?.keyCode, 42)
        XCTAssertEqual(zoomIn?.flags, [.maskCommand, .maskAlternate])
        XCTAssertEqual(zoomOut?.keyCode, 43)
        XCTAssertEqual(
            zoomOut?.flags,
            [.maskCommand, .maskShift, .maskAlternate]
        )
    }

    func testPageZoomFallsBackPerMissingLayoutCharacter() {
        let resolver = PageZoomShortcutResolver()
        let shortcuts = resolver.resolve(candidates: [
            KeyboardLayoutKeyCandidate(
                keyCode: 50,
                flags: [],
                characters: "+"
            )
        ])

        XCTAssertEqual(shortcuts.zoomIn.keyCode, 50)
        XCTAssertEqual(shortcuts.zoomOut, PageZoomShortcutSet.fallback.zoomOut)
    }

    func testPageZoomPrefersTypingAreaOverNumericKeypad() {
        let resolver = PageZoomShortcutResolver()
        let shortcuts = resolver.resolve(candidates: [
            KeyboardLayoutKeyCandidate(
                keyCode: 69,
                flags: [],
                characters: "+"
            ),
            KeyboardLayoutKeyCandidate(
                keyCode: 24,
                flags: .maskShift,
                characters: "+"
            )
        ])

        XCTAssertEqual(shortcuts.zoomIn.keyCode, 24)
        XCTAssertEqual(shortcuts.zoomIn.flags, .maskShift)
    }

    func testPinchCapabilityFallsBackToPageZoom() {
        let resolver = ZoomOutputCapabilityResolver()

        XCTAssertEqual(
            resolver.effectiveBehavior(
                requested: .pinch,
                pinchEventsAvailable: false
            ),
            .page
        )
        XCTAssertEqual(
            resolver.effectiveBehavior(
                requested: .pinch,
                pinchEventsAvailable: true
            ),
            .pinch
        )
        XCTAssertEqual(
            resolver.effectiveBehavior(
                requested: .page,
                pinchEventsAvailable: false
            ),
            .page
        )
    }

    func testMagnificationFactoryCanDisableUndocumentedEventPath() {
        var factory = MagnificationEventFactory(allowsRuntimeEvents: false)

        XCTAssertFalse(factory.isAvailable())
        XCTAssertNil(
            factory.event(
                for: MagnificationEventDescriptor(
                    magnification: 0.1,
                    phase: .began
                )
            )
        )
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
