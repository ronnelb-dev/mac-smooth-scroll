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
}
