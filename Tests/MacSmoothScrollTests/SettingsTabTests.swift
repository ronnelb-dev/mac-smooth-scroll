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
        }
    }

    func testTabResolutionDefaultsToScrolling() {
        XCTAssertEqual(SettingsTab.resolve(nil), .scrolling)
        XCTAssertEqual(SettingsTab.resolve("invalid"), .scrolling)
        XCTAssertEqual(SettingsTab.resolve("advancedScrolling"), .scrolling)
        XCTAssertEqual(SettingsTab.resolve("systemHealth"), .app)
        XCTAssertEqual(SettingsTab.resolve("app"), .app)
    }
}
