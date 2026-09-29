import CoreGraphics
import XCTest
@testable import MacSmoothScroll

final class BackForwardButtonHandlerTests: XCTestCase {
    func testStandardAuxiliaryButtonsMapToNavigation() {
        let back = CGEvent(mouseEventSource: nil, mouseType: .otherMouseDown,
                           mouseCursorPosition: .zero, mouseButton: .left)
        back?.setIntegerValueField(.mouseEventButtonNumber, value: 3)
        XCTAssertEqual(BackForwardButtonHandler.action(for: back!), .back)

        let forward = CGEvent(mouseEventSource: nil, mouseType: .otherMouseDown,
                              mouseCursorPosition: .zero, mouseButton: .left)
        forward?.setIntegerValueField(.mouseEventButtonNumber, value: 4)
        XCTAssertEqual(BackForwardButtonHandler.action(for: forward!), .forward)
    }

    func testCustomAuxiliaryButtonsMapToNavigation() {
        let assignments = MouseButtonAssignments(
            backButtonNumber: 8,
            forwardButtonNumber: 9
        )!
        let back = auxiliaryEvent(type: .otherMouseDown, buttonNumber: 8)
        let forward = auxiliaryEvent(type: .otherMouseDown, buttonNumber: 9)
        let oldDefault = auxiliaryEvent(type: .otherMouseDown, buttonNumber: 3)

        XCTAssertEqual(
            BackForwardButtonHandler.action(
                for: back,
                assignments: assignments
            ),
            .back
        )
        XCTAssertEqual(
            BackForwardButtonHandler.action(
                for: forward,
                assignments: assignments
            ),
            .forward
        )
        XCTAssertNil(
            BackForwardButtonHandler.action(
                for: oldDefault,
                assignments: assignments
            )
        )
    }

    func testAssignmentsValidateSupportedDistinctButtonNumbers() {
        XCTAssertNil(
            MouseButtonAssignments(backButtonNumber: 2, forwardButtonNumber: 4)
        )
        XCTAssertNil(
            MouseButtonAssignments(backButtonNumber: 3, forwardButtonNumber: 32)
        )
        XCTAssertNil(
            MouseButtonAssignments(backButtonNumber: 7, forwardButtonNumber: 7)
        )
        XCTAssertEqual(
            MouseButtonAssignments.resolved(
                backButtonNumber: 7,
                forwardButtonNumber: 7
            ),
            .defaults
        )
    }

    func testCaptureSessionCompletesAtomicallyAndRejectsDuplicates() {
        var session = MouseButtonCaptureSession()
        session.start()
        XCTAssertEqual(session.state, .awaitingBack)
        XCTAssertFalse(session.capture(buttonNumber: 2))
        XCTAssertEqual(session.state, .awaitingBack)

        XCTAssertTrue(session.capture(buttonNumber: 8))
        XCTAssertEqual(
            session.state,
            .awaitingForward(backButtonNumber: 8, validationMessage: nil)
        )
        XCTAssertTrue(session.capture(buttonNumber: 8))
        XCTAssertEqual(
            session.state,
            .awaitingForward(
                backButtonNumber: 8,
                validationMessage: "Choose a different button for Forward."
            )
        )
        XCTAssertTrue(session.capture(buttonNumber: 9))
        XCTAssertEqual(
            session.state,
            .completed(
                MouseButtonAssignments(
                    backButtonNumber: 8,
                    forwardButtonNumber: 9
                )!
            )
        )
    }

    func testCaptureCancellationDoesNotCompleteAssignments() {
        var session = MouseButtonCaptureSession()
        session.start()
        XCTAssertTrue(session.capture(buttonNumber: 8))
        session.cancel()
        XCTAssertEqual(session.state, .cancelled)
        XCTAssertFalse(session.capture(buttonNumber: 9))
    }

    func testConsumptionTrackerConsumesOnlyMatchingButtonUp() {
        var tracker = MouseButtonConsumptionTracker()
        tracker.record(8)

        XCTAssertFalse(
            tracker.consumeRelease(
                for: auxiliaryEvent(type: .otherMouseDown, buttonNumber: 8)
            )
        )
        XCTAssertFalse(
            tracker.consumeRelease(
                for: auxiliaryEvent(type: .otherMouseUp, buttonNumber: 9)
            )
        )
        XCTAssertTrue(
            tracker.consumeRelease(
                for: auxiliaryEvent(type: .otherMouseUp, buttonNumber: 8)
            )
        )
        XCTAssertTrue(tracker.isEmpty)
        XCTAssertFalse(
            tracker.consumeRelease(
                for: auxiliaryEvent(type: .otherMouseUp, buttonNumber: 8)
            )
        )
    }

    func testUnrelatedEventsAreIgnored() {
        let event = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown,
                            mouseCursorPosition: .zero, mouseButton: .left)
        XCTAssertNil(BackForwardButtonHandler.action(for: event!))

        let unsupportedButton = CGEvent(
            mouseEventSource: nil,
            mouseType: .otherMouseDown,
            mouseCursorPosition: .zero,
            mouseButton: .left
        )!
        unsupportedButton.setIntegerValueField(
            .mouseEventButtonNumber,
            value: 5
        )
        XCTAssertNil(BackForwardButtonHandler.action(for: unsupportedButton))
    }

    func testDisabledFeaturePassesRecognizedButtonsThrough() {
        let event = CGEvent(
            mouseEventSource: nil,
            mouseType: .otherMouseDown,
            mouseCursorPosition: .zero,
            mouseButton: .left
        )!
        event.setIntegerValueField(.mouseEventButtonNumber, value: 3)

        XCTAssertNil(
            BackForwardButtonHandler.action(for: event, isEnabled: false)
        )
    }

    func testDispatchConsumesOnlyAfterShortcutDeliverySucceeds() {
        let event = CGEvent(
            mouseEventSource: nil,
            mouseType: .otherMouseDown,
            mouseCursorPosition: .zero,
            mouseButton: .left
        )!
        event.setIntegerValueField(.mouseEventButtonNumber, value: 3)

        XCTAssertFalse(
            BackForwardButtonHandler.dispatch(
                event: event,
                isEnabled: true,
                bundleIdentifier: "com.apple.Safari",
                sender: { _ in false }
            )
        )
        XCTAssertTrue(
            BackForwardButtonHandler.dispatch(
                event: event,
                isEnabled: true,
                bundleIdentifier: "com.apple.Safari",
                sender: { shortcut in
                    shortcut == .init(keyCode: 33, flags: .maskCommand)
                }
            )
        )
    }

    func testKnownAppsUseShortcutsThatDoNotConflictWithEditorIndentation() {
        let identifiers = [
            "com.microsoft.VSCode",
            "com.microsoft.VSCodeInsiders",
            "com.todesktop.230313mzl4w4u92",
            "com.vscodium.preview",
            "com.exafunction.windsurf.preview",
            "com.codeium.windsurf",
            "dev.zed.Zed-Preview"
        ]
        for identifier in identifiers {
            XCTAssertEqual(
                BackForwardButtonHandler.profile(for: identifier),
                .codeEditor,
                identifier
            )
        }
        XCTAssertEqual(
            BackForwardButtonHandler.shortcut(
                for: .back,
                bundleIdentifier: "com.microsoft.VSCode"
            ),
            .init(keyCode: 27, flags: .maskControl)
        )
        XCTAssertEqual(
            BackForwardButtonHandler.shortcut(
                for: .forward,
                bundleIdentifier: "com.todesktop.230313mzl4w4u92"
            ),
            .init(keyCode: 27, flags: [.maskControl, .maskShift])
        )
    }

    func testAcrobatUsesPreviousAndNextViewShortcuts() {
        XCTAssertEqual(
            BackForwardButtonHandler.profile(for: "com.adobe.Acrobat.Pro"),
            .acrobat
        )
        XCTAssertEqual(
            BackForwardButtonHandler.profile(for: "com.adobe.Reader.preview"),
            .acrobat
        )
        XCTAssertEqual(
            BackForwardButtonHandler.shortcut(
                for: .back,
                bundleIdentifier: "com.adobe.Acrobat.Pro"
            ),
            .init(keyCode: 123, flags: .maskCommand)
        )
        XCTAssertEqual(
            BackForwardButtonHandler.shortcut(
                for: .forward,
                bundleIdentifier: "org.zotero.zotero"
            ),
            .init(keyCode: 30, flags: .maskCommand)
        )
        XCTAssertEqual(
            BackForwardButtonHandler.shortcut(
                for: .back,
                bundleIdentifier: "com.apple.Preview"
            ),
            .init(keyCode: 33, flags: .maskCommand)
        )
        XCTAssertEqual(
            BackForwardButtonHandler.profile(for: "com.example.Unknown"),
            .standard
        )
    }

    private func auxiliaryEvent(
        type: CGEventType,
        buttonNumber: Int64
    ) -> CGEvent {
        let mouseType: CGEventType = type == .otherMouseUp
            ? .otherMouseUp
            : .otherMouseDown
        let event = CGEvent(
            mouseEventSource: nil,
            mouseType: mouseType,
            mouseCursorPosition: .zero,
            mouseButton: .left
        )!
        event.setIntegerValueField(
            .mouseEventButtonNumber,
            value: buttonNumber
        )
        return event
    }
}
