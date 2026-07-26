import Foundation
import XCTest
@testable import MacSmoothScroll

final class ScrollSettingsTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "MacSmoothScrollTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testDocumentedDefaults() {
        let settings = makeSettings()

        XCTAssertTrue(settings.isEnabled)
        XCTAssertEqual(settings.smoothness, .high)
        XCTAssertEqual(settings.speed, .medium)
        XCTAssertEqual(settings.feel, .balanced)
        XCTAssertTrue(settings.trackpadSimulation)
        XCTAssertFalse(settings.reverseDirection)
        XCTAssertTrue(settings.adaptivePrecision)
        XCTAssertEqual(settings.horizontalModifier, .shift)
        XCTAssertEqual(settings.zoomModifier, .command)
        XCTAssertEqual(settings.swiftModifier, .control)
        XCTAssertEqual(settings.preciseModifier, .option)
        XCTAssertTrue(settings.showInMenuBar)
        XCTAssertFalse(settings.launchAtLogin)
    }

    func testSettingsPersistAcrossInstances() {
        let settings = makeSettings()
        settings.isEnabled = false
        settings.smoothness = .low
        settings.speed = .fast
        settings.feel = .responsive
        settings.trackpadSimulation = false
        settings.reverseDirection = true
        settings.adaptivePrecision = false
        settings.horizontalModifier = .control
        settings.zoomModifier = .option
        settings.swiftModifier = .shift
        settings.preciseModifier = .command
        settings.showInMenuBar = false
        settings.launchAtLogin = true

        let reloaded = makeSettings()
        XCTAssertFalse(reloaded.isEnabled)
        XCTAssertEqual(reloaded.smoothness, .low)
        XCTAssertEqual(reloaded.speed, .fast)
        XCTAssertEqual(reloaded.feel, .responsive)
        XCTAssertFalse(reloaded.trackpadSimulation)
        XCTAssertTrue(reloaded.reverseDirection)
        XCTAssertFalse(reloaded.adaptivePrecision)
        XCTAssertEqual(reloaded.horizontalModifier, .control)
        XCTAssertEqual(reloaded.zoomModifier, .option)
        XCTAssertEqual(reloaded.swiftModifier, .shift)
        XCTAssertEqual(reloaded.preciseModifier, .command)
        XCTAssertFalse(reloaded.showInMenuBar)
        XCTAssertTrue(reloaded.launchAtLogin)
    }

    func testResetRestoresScrollingDefaultsWithoutChangingAppPreferences() {
        let settings = makeSettings()
        settings.isEnabled = false
        settings.smoothness = .low
        settings.speed = .fast
        settings.feel = .glide
        settings.trackpadSimulation = false
        settings.reverseDirection = true
        settings.adaptivePrecision = false
        settings.horizontalModifier = .none
        settings.zoomModifier = .none
        settings.swiftModifier = .none
        settings.preciseModifier = .none
        settings.showInMenuBar = false
        settings.launchAtLogin = true

        settings.resetDefaults()

        XCTAssertTrue(settings.isEnabled)
        XCTAssertEqual(settings.smoothness, .high)
        XCTAssertEqual(settings.speed, .medium)
        XCTAssertEqual(settings.feel, .balanced)
        XCTAssertTrue(settings.trackpadSimulation)
        XCTAssertFalse(settings.reverseDirection)
        XCTAssertTrue(settings.adaptivePrecision)
        XCTAssertEqual(settings.horizontalModifier, .shift)
        XCTAssertEqual(settings.zoomModifier, .command)
        XCTAssertEqual(settings.swiftModifier, .control)
        XCTAssertEqual(settings.preciseModifier, .option)
        XCTAssertFalse(settings.showInMenuBar)
        XCTAssertTrue(settings.launchAtLogin)
    }

    func testPersistentChangeInvokesChangeCallback() {
        let settings = makeSettings()
        var changeCount = 0
        settings.onChange = {
            changeCount += 1
        }

        settings.speed = .slow

        XCTAssertEqual(changeCount, 1)
    }

    private func makeSettings() -> ScrollSettings {
        ScrollSettings(
            defaults: defaults,
            managesLaunchAtLogin: false
        )
    }
}
