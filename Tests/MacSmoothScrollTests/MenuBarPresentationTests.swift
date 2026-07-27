import XCTest
@testable import MacSmoothScroll

final class MenuBarPresentationTests: XCTestCase {
    func testEveryEngineStatusHasACompleteMenuBarPresentation() {
        let statuses: [ScrollEngineStatus] = [
            .waiting,
            .active,
            .disabled,
            .permissionBlocked,
            .driverConflict,
            .startFailed
        ]

        let presentations = statuses.map {
            MenuBarPresentation.make(isEnabled: $0 != .disabled, engineStatus: $0)
        }

        XCTAssertEqual(Set(presentations.map(\.statusTitle)).count, statuses.count)
        XCTAssertTrue(presentations.allSatisfy { !$0.statusSymbolName.isEmpty })
        XCTAssertTrue(presentations.allSatisfy { !$0.statusItemSymbolName.isEmpty })
        XCTAssertTrue(
            presentations.allSatisfy {
                $0.statusItemAccessibilityLabel.contains($0.statusTitle)
            }
        )
    }

    func testHealthyAndDisabledStatesDoNotOfferRecovery() {
        XCTAssertEqual(
            MenuBarPresentation.make(isEnabled: true, engineStatus: .active).recoveryAction,
            .none
        )
        XCTAssertEqual(
            MenuBarPresentation.make(isEnabled: false, engineStatus: .disabled).recoveryAction,
            .none
        )
    }

    func testBlockedStatesOfferContextualRecovery() {
        XCTAssertEqual(
            MenuBarPresentation.make(
                isEnabled: true,
                engineStatus: .permissionBlocked
            ).recoveryAction,
            .openAccessibilitySettings
        )
        XCTAssertEqual(
            MenuBarPresentation.make(
                isEnabled: true,
                engineStatus: .driverConflict
            ).recoveryAction,
            .quitMacMouseFix
        )
        XCTAssertEqual(
            MenuBarPresentation.make(
                isEnabled: true,
                engineStatus: .startFailed
            ).recoveryAction,
            .retryEngine
        )
    }

    func testToggleStateUsesTheSavedPreference() {
        XCTAssertFalse(
            MenuBarPresentation.make(
                isEnabled: false,
                engineStatus: .waiting
            ).smoothScrollingIsOn
        )
        XCTAssertTrue(
            MenuBarPresentation.make(
                isEnabled: true,
                engineStatus: .waiting
            ).smoothScrollingIsOn
        )
    }

    func testRecoveryTitlesAreExplicit() {
        XCTAssertNil(MenuBarRecoveryAction.none.title)
        XCTAssertEqual(
            MenuBarRecoveryAction.openAccessibilitySettings.title,
            "Open Accessibility Settings…"
        )
        XCTAssertEqual(
            MenuBarRecoveryAction.quitMacMouseFix.title,
            "Quit Mac Mouse Fix"
        )
        XCTAssertEqual(
            MenuBarRecoveryAction.retryEngine.title,
            "Retry Scroll Engine"
        )
    }
}
