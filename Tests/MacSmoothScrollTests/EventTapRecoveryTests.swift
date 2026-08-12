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

    func testAutomaticRebuildsStopAfterBoundedAttempts() {
        var policy = EventTapRecoveryPolicy(
            maximumRebuildAttempts: 3,
            rebuildAttemptWindow: 30
        )

        XCTAssertEqual(policy.action(for: .healthCheck, at: 1), .rebuild)
        policy.didCompleteRebuild()
        XCTAssertEqual(policy.action(for: .healthCheck, at: 2), .rebuild)
        policy.didCompleteRebuild()
        XCTAssertEqual(policy.action(for: .healthCheck, at: 3), .rebuild)
        policy.didCompleteRebuild()
        XCTAssertEqual(policy.action(for: .healthCheck, at: 4), .stop)
    }

    func testCompletedRebuildKeepsTheAttemptBudget() {
        var policy = EventTapRecoveryPolicy(
            maximumRebuildAttempts: 1,
            rebuildAttemptWindow: 30
        )

        XCTAssertEqual(policy.action(for: .healthCheck, at: 1), .rebuild)
        policy.didCompleteRebuild()

        XCTAssertEqual(policy.action(for: .healthCheck, at: 2), .stop)
    }

    func testExpiredRebuildAttemptsAllowRecoveryAgain() {
        var policy = EventTapRecoveryPolicy(
            maximumRebuildAttempts: 1,
            rebuildAttemptWindow: 30
        )

        XCTAssertEqual(policy.action(for: .healthCheck, at: 1), .rebuild)
        XCTAssertEqual(policy.action(for: .healthCheck, at: 31.01), .rebuild)
    }

    func testInvalidTimestampStopsAutomaticRecovery() {
        var policy = EventTapRecoveryPolicy()

        XCTAssertEqual(policy.action(for: .timeout, at: .nan), .stop)
        XCTAssertEqual(policy.action(for: .healthCheck, at: .infinity), .stop)
    }

    func testResetClearsRepeatedDisableHistory() {
        var policy = EventTapRecoveryPolicy()
        _ = policy.action(for: .timeout, at: 1)
        _ = policy.action(for: .timeout, at: 2)

        policy.reset()

        XCTAssertEqual(policy.action(for: .timeout, at: 3), .reenable)
        XCTAssertEqual(policy.action(for: .healthCheck, at: 3), .rebuild)
    }

    func testResetClearsRebuildBudget() {
        var policy = EventTapRecoveryPolicy(
            maximumRebuildAttempts: 1,
            rebuildAttemptWindow: 30
        )
        XCTAssertEqual(policy.action(for: .healthCheck, at: 1), .rebuild)
        XCTAssertEqual(policy.action(for: .healthCheck, at: 2), .stop)

        policy.reset()

        XCTAssertEqual(policy.action(for: .healthCheck, at: 3), .rebuild)
    }
}
