import Foundation
import XCTest
@testable import MacSmoothScrollLauncher

final class LoginItemLauncherTests: XCTestCase {
    private enum TestError: Error {
        case launchFailed
    }

    func testResolvesMainApplicationFromEmbeddedHelper() {
        let helperURL = URL(
            fileURLWithPath:
                "/Applications/Mac Smooth Scroll.app/Contents/Library/LoginItems/Mac Smooth Scroll Launcher.app"
        )

        XCTAssertEqual(
            LoginItemLauncher.mainApplicationURL(from: helperURL).path,
            "/Applications/Mac Smooth Scroll.app"
        )
    }

    func testRetriesTransientFailuresAndStopsAfterSuccess() async throws {
        var attempts = 0
        var delays: [UInt64] = []

        try await LoginItemLauncher.launch(
            maximumAttempts: 4,
            retryDelayNanoseconds: 10,
            openApplication: {
                attempts += 1
                if attempts < 3 {
                    throw TestError.launchFailed
                }
            },
            sleep: { delay in
                delays.append(delay)
            }
        )

        XCTAssertEqual(attempts, 3)
        XCTAssertEqual(delays, [10, 20])
    }

    func testThrowsAfterMaximumAttempts() async {
        var attempts = 0

        do {
            try await LoginItemLauncher.launch(
                maximumAttempts: 3,
                retryDelayNanoseconds: 0,
                openApplication: {
                    attempts += 1
                    throw TestError.launchFailed
                },
                sleep: { _ in }
            )
            XCTFail("Expected the launcher to report its final failure.")
        } catch {
            XCTAssertEqual(attempts, 3)
        }
    }
}
