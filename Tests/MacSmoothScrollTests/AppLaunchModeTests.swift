import XCTest
@testable import MacSmoothScroll

final class AppLaunchModeTests: XCTestCase {
    func testOrdinaryLaunchUsesForegroundMode() {
        XCTAssertEqual(
            AppLaunchMode(arguments: ["/Applications/Mac Smooth Scroll.app/Contents/MacOS/MacSmoothScroll"]),
            .foreground
        )
    }

    func testBackgroundFlagUsesBackgroundMode() {
        XCTAssertEqual(
            AppLaunchMode(arguments: ["MacSmoothScroll", "--background"]),
            .background
        )
    }

    func testOnlyExactBackgroundFlagIsRecognized() {
        XCTAssertEqual(
            AppLaunchMode(arguments: ["MacSmoothScroll", "--background-task"]),
            .foreground
        )
    }
}
