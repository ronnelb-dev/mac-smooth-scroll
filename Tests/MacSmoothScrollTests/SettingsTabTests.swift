import XCTest
@testable import MacSmoothScroll

final class SettingsTabTests: XCTestCase {
    func testTabsHaveStableOrderAndIdentifiers() {
        XCTAssertEqual(
            SettingsTab.allCases,
            [
                .scrolling,
                .modifierKeys,
                .app,
            ]
        )
        XCTAssertEqual(SettingsTab.allCases.map(\.rawValue), [
            "scrolling",
            "modifierKeys",
            "app",
        ])
    }

    func testEveryTabHasAVisibleTitleAndSymbol() {
        for tab in SettingsTab.allCases {
            XCTAssertFalse(tab.title.isEmpty)
            XCTAssertFalse(tab.symbolName.isEmpty)
            XCTAssertFalse(tab.keyboardShortcutDescription.isEmpty)
        }
        XCTAssertEqual(
            SettingsTab.allCases.map(\.keyboardShortcutCharacter),
            ["1", "2", "3"]
        )
    }

    func testArrowNavigationWrapsAcrossTabs() {
        XCTAssertEqual(SettingsTab.scrolling.adjacent(.previous), .app)
        XCTAssertEqual(SettingsTab.scrolling.adjacent(.next), .modifierKeys)
        XCTAssertEqual(SettingsTab.modifierKeys.adjacent(.previous), .scrolling)
        XCTAssertEqual(SettingsTab.modifierKeys.adjacent(.next), .app)
        XCTAssertEqual(SettingsTab.app.adjacent(.next), .scrolling)
    }

    func testTabResolutionDefaultsToScrolling() {
        XCTAssertEqual(SettingsTab.resolve(nil), .scrolling)
        XCTAssertEqual(SettingsTab.resolve("invalid"), .scrolling)
        XCTAssertEqual(SettingsTab.resolve("advancedScrolling"), .scrolling)
        XCTAssertEqual(SettingsTab.resolve("systemHealth"), .app)
        XCTAssertEqual(SettingsTab.resolve("app"), .app)
    }
}
