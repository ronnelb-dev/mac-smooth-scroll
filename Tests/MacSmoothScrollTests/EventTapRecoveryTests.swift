import XCTest
@testable import MacSmoothScroll

final class EventTapRecoveryTests: XCTestCase {
    func testIsolatedDisableEventsAreReenabled() {
        var policy = EventTapRecoveryPolicy()

        XCTAssertEqual(policy.action(for: .timeout, at: 1), .reenable)
        XCTAssertEqual(policy.action(for: .userInput, at: 2), .reenable)
    }

    func testRepeatedDisableEventsRebuildTheTap() {
        var policy = EventTapRecoveryPolicy()

        XCTAssertEqual(policy.action(for: .timeout, at: 1), .reenable)
        XCTAssertEqual(policy.action(for: .timeout, at: 2), .reenable)
        XCTAssertEqual(policy.action(for: .timeout, at: 3), .rebuild)
    }

    func testOldDisableEventsDoNotTriggerARebuild() {
        var policy = EventTapRecoveryPolicy()

        XCTAssertEqual(policy.action(for: .timeout, at: 1), .reenable)
        XCTAssertEqual(policy.action(for: .timeout, at: 2), .reenable)
        XCTAssertEqual(policy.action(for: .timeout, at: 12.01), .reenable)
    }

    func testHealthCheckRebuildsASilentlyDisabledTap() {
        var policy = EventTapRecoveryPolicy()

        XCTAssertEqual(policy.action(for: .healthCheck, at: 1), .rebuild)
    }

    func testResetClearsRepeatedDisableHistory() {
        var policy = EventTapRecoveryPolicy()
        _ = policy.action(for: .timeout, at: 1)
        _ = policy.action(for: .timeout, at: 2)

        policy.reset()

        XCTAssertEqual(policy.action(for: .timeout, at: 3), .reenable)
    }
}
