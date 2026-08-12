import XCTest
@testable import MacSmoothScroll

final class ModifierConflictGuidanceTests: XCTestCase {
    private let advisor = ModifierConflictAdvisor()

    func testDistinctAssignmentsNeedNoGuidance() {
        XCTAssertTrue(
            guidance(
                horizontal: .shift,
                zoom: .command,
                faster: .control,
                precision: .option,
                bypass: .none
            ).isEmpty
        )
    }

    func testNoneAssignmentsAreIgnored() {
        XCTAssertTrue(
            guidance(
                horizontal: .none,
                zoom: .none,
                faster: .none,
                precision: .none,
                bypass: .none
            ).isEmpty
        )
    }

    func testHorizontalAndFasterAreCompatible() {
        let item = guidance(
            horizontal: .shift,
            zoom: .command,
            faster: .shift,
            precision: .option,
            bypass: .none
        ).first

        XCTAssertEqual(item?.tone, .compatible)
        XCTAssertEqual(item?.assignments, [.horizontal, .faster])
        XCTAssertEqual(item?.outcome, "These actions combine when the key is held.")
    }

    func testHorizontalAndPrecisionAreCompatible() {
        let item = guidance(
            horizontal: .option,
            zoom: .command,
            faster: .control,
            precision: .option,
            bypass: .none
        ).first

        XCTAssertEqual(item?.tone, .compatible)
        XCTAssertEqual(item?.assignments, [.horizontal, .precision])
        XCTAssertEqual(item?.outcome, "These actions combine when the key is held.")
    }

    func testPrecisionOverridesFasterAndSuppressesZoom() {
        let item = guidance(
            horizontal: .shift,
            zoom: .option,
            faster: .option,
            precision: .option,
            bypass: .none
        ).first

        XCTAssertEqual(item?.tone, .priority)
        XCTAssertEqual(
            item?.outcome,
            "Precision overrides Faster; Precision suppresses Zoom."
        )
    }

    func testHorizontalAndZoomExplainConditionalPriority() {
        let item = guidance(
            horizontal: .command,
            zoom: .command,
            faster: .control,
            precision: .option,
            bypass: .none
        ).first

        XCTAssertEqual(item?.tone, .priority)
        XCTAssertEqual(
            item?.outcome,
            "Horizontal wins for vertical-dominant input; otherwise Zoom can run."
        )
    }

    func testBypassWinsEverySharedAssignment() {
        let item = guidance(
            horizontal: .control,
            zoom: .control,
            faster: .control,
            precision: .control,
            bypass: .control
        ).first

        XCTAssertEqual(item?.tone, .priority)
        XCTAssertEqual(
            item?.outcome,
            "Bypass wins and sends the wheel event natively."
        )
    }

    func testGuidanceOrderFollowsStableModifierOrder() {
        let items = guidance(
            horizontal: .shift,
            zoom: .command,
            faster: .shift,
            precision: .command,
            bypass: .none
        )

        XCTAssertEqual(items.map(\.key), [.shift, .command])
    }

    private func guidance(
        horizontal: ModifierKey,
        zoom: ModifierKey,
        faster: ModifierKey,
        precision: ModifierKey,
        bypass: ModifierKey
    ) -> [ModifierConflictGuidance] {
        advisor.guidance(
            horizontal: horizontal,
            zoom: zoom,
            faster: faster,
            precision: precision,
            bypass: bypass
        )
    }
}
