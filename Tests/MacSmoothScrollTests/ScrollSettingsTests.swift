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
        XCTAssertTrue(settings.minimumStepEnabled)
        XCTAssertEqual(settings.minimumStepDistance, 18)
        XCTAssertEqual(settings.feel, .balanced)
        XCTAssertTrue(settings.trackpadSimulation)
        XCTAssertFalse(settings.reverseDirection)
        XCTAssertTrue(settings.adaptivePrecision)
        XCTAssertTrue(settings.accelerationEnabled)
        XCTAssertTrue(settings.axisLockEnabled)
        XCTAssertEqual(settings.horizontalModifier, .shift)
        XCTAssertEqual(settings.zoomModifier, .command)
        XCTAssertEqual(settings.swiftModifier, .control)
        XCTAssertEqual(settings.preciseModifier, .option)
        XCTAssertTrue(settings.showInMenuBar)
        XCTAssertFalse(settings.launchAtLogin)
        XCTAssertEqual(settings.launchAtLoginHealthStatus, .disabled)
        XCTAssertFalse(settings.onboardingCompleted)
        XCTAssertFalse(settings.isSetupPresented)
        XCTAssertEqual(settings.selectedTab, .scrolling)
    }

    func testSettingsPersistAcrossInstances() {
        let settings = makeSettings()
        settings.isEnabled = false
        settings.smoothness = .low
        settings.speed = .fast
        settings.minimumStepEnabled = false
        settings.minimumStepDistance = 33.6
        settings.feel = .responsive
        settings.trackpadSimulation = false
        settings.reverseDirection = true
        settings.adaptivePrecision = false
        settings.accelerationEnabled = false
        settings.axisLockEnabled = false
        settings.horizontalModifier = .control
        settings.zoomModifier = .option
        settings.swiftModifier = .shift
        settings.preciseModifier = .command
        settings.showInMenuBar = false
        settings.launchAtLogin = true
        settings.selectedTab = .app

        let reloaded = makeSettings()
        XCTAssertFalse(reloaded.isEnabled)
        XCTAssertEqual(reloaded.smoothness, .low)
        XCTAssertEqual(reloaded.speed, .fast)
        XCTAssertFalse(reloaded.minimumStepEnabled)
        XCTAssertEqual(reloaded.minimumStepDistance, 33.6)
        XCTAssertEqual(reloaded.feel, .responsive)
        XCTAssertFalse(reloaded.trackpadSimulation)
        XCTAssertTrue(reloaded.reverseDirection)
        XCTAssertFalse(reloaded.adaptivePrecision)
        XCTAssertFalse(reloaded.accelerationEnabled)
        XCTAssertFalse(reloaded.axisLockEnabled)
        XCTAssertEqual(reloaded.horizontalModifier, .control)
        XCTAssertEqual(reloaded.zoomModifier, .option)
        XCTAssertEqual(reloaded.swiftModifier, .shift)
        XCTAssertEqual(reloaded.preciseModifier, .command)
        XCTAssertFalse(reloaded.showInMenuBar)
        XCTAssertTrue(reloaded.launchAtLogin)
        XCTAssertEqual(reloaded.selectedTab, .app)
    }

    func testResetRestoresScrollingDefaultsWithoutChangingAppPreferences() {
        let settings = makeSettings()
        settings.isEnabled = false
        settings.smoothness = .low
        settings.speed = .fast
        settings.minimumStepEnabled = false
        settings.minimumStepDistance = 75
        settings.feel = .glide
        settings.trackpadSimulation = false
        settings.reverseDirection = true
        settings.adaptivePrecision = false
        settings.accelerationEnabled = false
        settings.axisLockEnabled = false
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
        XCTAssertTrue(settings.minimumStepEnabled)
        XCTAssertEqual(settings.minimumStepDistance, 18)
        XCTAssertEqual(settings.feel, .balanced)
        XCTAssertTrue(settings.trackpadSimulation)
        XCTAssertFalse(settings.reverseDirection)
        XCTAssertTrue(settings.adaptivePrecision)
        XCTAssertTrue(settings.accelerationEnabled)
        XCTAssertTrue(settings.axisLockEnabled)
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

    func testTabSelectionPersistsWithoutRefreshingTheScrollEngine() {
        let settings = makeSettings()
        var changeCount = 0
        settings.onChange = {
            changeCount += 1
        }

        settings.selectedTab = .app

        XCTAssertEqual(changeCount, 0)
        XCTAssertEqual(makeSettings().selectedTab, .app)
    }

    func testInvalidPersistedTabFallsBackToScrolling() {
        defaults.set("unknown-tab", forKey: "settings.selectedTab")

        XCTAssertEqual(makeSettings().selectedTab, .scrolling)
    }

    func testLegacyMergedTabsResolveToTheirNewDestinations() {
        defaults.set("advancedScrolling", forKey: "settings.selectedTab")
        XCTAssertEqual(makeSettings().selectedTab, .scrolling)

        defaults.set("systemHealth", forKey: "settings.selectedTab")
        XCTAssertEqual(makeSettings().selectedTab, .app)
    }

    func testStepRoundsAndClampsBeforePersisting() {
        let settings = makeSettings()

        settings.minimumStepDistance = 12.345
        XCTAssertEqual(settings.minimumStepDistance, 12.35, accuracy: 0.0001)

        settings.minimumStepDistance = -5
        XCTAssertEqual(settings.minimumStepDistance, 0.01, accuracy: 0.0001)

        settings.minimumStepDistance = 500
        XCTAssertEqual(settings.minimumStepDistance, 100, accuracy: 0.0001)

        let reloaded = makeSettings()
        XCTAssertEqual(reloaded.minimumStepDistance, 100, accuracy: 0.0001)
    }

    func testLegacySettingsEnableMinimumStepByDefault() {
        defaults.set(42.5, forKey: "scroll.step")

        let settings = makeSettings()

        XCTAssertTrue(settings.minimumStepEnabled)
        XCTAssertEqual(settings.minimumStepDistance, 42.5, accuracy: 0.0001)
    }

    func testLegacySettingsEnableAccelerationByDefault() {
        defaults.set(ScrollFeel.glide.rawValue, forKey: "scroll.feel")

        XCTAssertTrue(makeSettings().accelerationEnabled)
    }

    func testLegacySettingsEnableAxisLockByDefault() {
        defaults.set(ScrollSpeed.fast.rawValue, forKey: "scroll.speed")

        XCTAssertTrue(makeSettings().axisLockEnabled)
    }

    func testDisabledMinimumStepRetainsItsValueAcrossInstances() {
        let settings = makeSettings()
        settings.minimumStepDistance = 33.6
        settings.minimumStepEnabled = false

        let reloaded = makeSettings()

        XCTAssertFalse(reloaded.minimumStepEnabled)
        XCTAssertEqual(reloaded.minimumStepDistance, 33.6, accuracy: 0.0001)
    }

    func testNonFiniteStepFallsBackToDefault() {
        let settings = makeSettings()

        settings.minimumStepDistance = .nan

        XCTAssertEqual(
            settings.minimumStepDistance,
            ScrollStep.defaultValue,
            accuracy: 0.0001
        )
    }

    func testInitialSetupPresentsUntilCompleted() {
        let settings = makeSettings()

        settings.presentInitialSetupIfNeeded()
        XCTAssertTrue(settings.isSetupPresented)

        settings.dismissSetup()
        XCTAssertFalse(settings.isSetupPresented)
        XCTAssertFalse(settings.onboardingCompleted)

        settings.presentInitialSetupIfNeeded()
        XCTAssertTrue(settings.isSetupPresented)
    }

    func testCompletingSetupPersistsAndPreventsAutomaticPresentation() {
        let settings = makeSettings()
        settings.presentInitialSetupIfNeeded()

        settings.completeSetup()

        XCTAssertTrue(settings.onboardingCompleted)
        XCTAssertFalse(settings.isSetupPresented)

        let reloaded = makeSettings()
        XCTAssertTrue(reloaded.onboardingCompleted)
        reloaded.presentInitialSetupIfNeeded()
        XCTAssertFalse(reloaded.isSetupPresented)
    }

    func testCompletedSetupCanBePresentedAgainWithoutChangingPreferences() {
        let settings = makeSettings()
        settings.speed = .fast
        settings.completeSetup()

        settings.presentSetup()

        XCTAssertTrue(settings.isSetupPresented)
        XCTAssertTrue(settings.onboardingCompleted)
        XCTAssertEqual(settings.speed, .fast)
    }

    func testApplicationsLocationDetection() {
        XCTAssertTrue(
            FirstRunSetup.isInstalledInApplications(
                URL(fileURLWithPath: "/Applications/Mac Smooth Scroll.app")
            )
        )
        XCTAssertFalse(
            FirstRunSetup.isInstalledInApplications(
                URL(fileURLWithPath: "/Users/example/Downloads/Mac Smooth Scroll.app")
            )
        )
        XCTAssertFalse(
            FirstRunSetup.isInstalledInApplications(
                URL(fileURLWithPath: "/Volumes/Mac Smooth Scroll/Mac Smooth Scroll.app")
            )
        )
    }

    func testStepFormattingAndKeyboardSizedAdjustments() {
        XCTAssertEqual(ScrollStep.formatted(18), "18.00")
        XCTAssertEqual(ScrollStep.formatted(12.345), "12.35")
        XCTAssertEqual(ScrollStep.adjusted(18, bySteps: 1), 18.01, accuracy: 0.0001)
        XCTAssertEqual(ScrollStep.adjusted(18, bySteps: -1), 17.99, accuracy: 0.0001)
        XCTAssertEqual(
            ScrollStep.adjusted(ScrollStep.maximum, bySteps: 1),
            ScrollStep.maximum,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            ScrollStep.adjusted(ScrollStep.minimum, bySteps: -1),
            ScrollStep.minimum,
            accuracy: 0.0001
        )
    }

    func testMinimumStepCanResetWithoutChangingOtherSettings() {
        let settings = makeSettings()
        settings.minimumStepEnabled = false
        settings.minimumStepDistance = 72
        settings.speed = .fast

        settings.resetMinimumStepDistance()

        XCTAssertTrue(settings.minimumStepEnabled)
        XCTAssertEqual(settings.minimumStepDistance, ScrollStep.defaultValue)
        XCTAssertEqual(settings.speed, .fast)
    }

    private func makeSettings() -> ScrollSettings {
        ScrollSettings(
            defaults: defaults,
            managesLaunchAtLogin: false
        )
    }
}
