import XCTest
@testable import MacSmoothScroll

final class MouseUtilityDetectionTests: XCTestCase {
    func testMacMouseFixAndHelperAreBlocking() {
        let detector = MouseUtilityDetector()

        let app = detector.detect(bundleIdentifiers: [
            "com.nuebling.mac-mouse-fix"
        ])
        let helper = detector.detect(bundleIdentifiers: [
            "com.nuebling.mac-mouse-fix.helper"
        ])

        XCTAssertTrue(app.blockingDriverRunning)
        XCTAssertTrue(helper.blockingDriverRunning)
        XCTAssertTrue(app.advisoryNames.isEmpty)
    }

    func testKnownUtilitiesAreAdvisoryAndDoNotBlockEngine() {
        let detection = MouseUtilityDetector().detect(bundleIdentifiers: [
            "com.caldis.Mos",
            "com.lujjjh.LinearMouse",
            "com.lujjjh.LinearMouse.helper"
        ])

        XCTAssertFalse(detection.blockingDriverRunning)
        XCTAssertEqual(detection.advisoryNames, ["LinearMouse", "Mos"])
    }

    func testDebugBundleIdentifiersAreRecognized() {
        let detection = MouseUtilityDetector().detect(bundleIdentifiers: [
            "com.caldis.Mos.debug",
            "com.lujjjh.dev.LinearMouse"
        ])

        XCTAssertEqual(detection.advisoryNames, ["LinearMouse", "Mos"])
    }

    func testUnknownApplicationsAreIgnored() {
        let detection = MouseUtilityDetector().detect(bundleIdentifiers: [
            "com.example.UnrelatedApp",
            ""
        ])

        XCTAssertFalse(detection.blockingDriverRunning)
        XCTAssertTrue(detection.advisoryNames.isEmpty)
    }

    func testDuplicateProcessesProduceOneUtilityEntry() {
        let detection = MouseUtilityDetector().detect(bundleIdentifiers: [
            "com.caldis.Mos",
            "com.caldis.Mos",
            "com.caldis.Mos.helper"
        ])

        XCTAssertEqual(detection.advisoryNames, ["Mos"])
    }

    func testBlockingConflictTakesPriorityWithoutHidingAdvisories() {
        let detection = MouseUtilityDetector().detect(bundleIdentifiers: [
            "com.nuebling.mac-mouse-fix.helper",
            "com.caldis.Mos"
        ])

        XCTAssertTrue(detection.blockingDriverRunning)
        XCTAssertEqual(detection.advisoryNames, ["Mos"])
    }
}
