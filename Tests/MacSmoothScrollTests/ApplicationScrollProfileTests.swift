import Foundation
import XCTest
@testable import MacSmoothScroll

final class ApplicationScrollProfileTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "ApplicationScrollProfileTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testExistingInstallationsStartWithNoProfiles() {
        XCTAssertTrue(makeSettings().applicationProfiles.isEmpty)
    }

    func testProfilePersistsAndOverridesOnlyItsExactApplication() {
        let settings = makeSettings()
        settings.horizontalModifier = .control
        var profile = makeProfile(
            bundleIdentifier: "com.example.Browser",
            name: "Browser",
            configuration: settings.applicationProfileConfiguration
        )
        profile.configuration.speed = .fast
        profile.configuration.feel = .glide
        profile.configuration.trackpadSimulation = false
        settings.upsertApplicationProfile(profile)

        let reloaded = makeSettings()
        let selected = reloaded.runtimeConfiguration(
            for: "com.example.Browser"
        )
        let defaultConfiguration = reloaded.runtimeConfiguration(
            for: "com.example.Editor"
        )

        XCTAssertEqual(reloaded.applicationProfiles, [profile])
        XCTAssertEqual(selected.profileBundleIdentifier, "com.example.Browser")
        XCTAssertEqual(selected.transform.speed, .fast)
        XCTAssertEqual(selected.feel, .glide)
        XCTAssertFalse(selected.trackpadSimulation)
        XCTAssertEqual(selected.transform.horizontalModifier, .control)
        XCTAssertNil(defaultConfiguration.profileBundleIdentifier)
        XCTAssertEqual(defaultConfiguration.transform.speed, .medium)
    }

    func testDisabledProfileRetainsValuesAndUsesDefaults() {
        let settings = makeSettings()
        var profile = makeProfile(
            bundleIdentifier: "com.example.Browser",
            name: "Browser",
            configuration: settings.applicationProfileConfiguration
        )
        profile.configuration.reverseDirection = true
        settings.upsertApplicationProfile(profile)
        settings.setApplicationProfileEnabled(
            false,
            bundleIdentifier: profile.bundleIdentifier
        )

        let selected = settings.runtimeConfiguration(
            for: profile.bundleIdentifier
        )
        XCTAssertNil(selected.profileBundleIdentifier)
        XCTAssertFalse(selected.transform.reverseDirection)
        XCTAssertTrue(settings.applicationProfiles[0].configuration.reverseDirection)
    }

    func testProfilesAreDeduplicatedSortedSanitizedAndRemovable() {
        let settings = makeSettings()
        var editor = makeProfile(
            bundleIdentifier: "com.example.Editor",
            name: "Zed",
            configuration: settings.applicationProfileConfiguration
        )
        editor.configuration.minimumStepDistance = 1_000
        settings.upsertApplicationProfile(editor)
        settings.upsertApplicationProfile(
            makeProfile(
                bundleIdentifier: "com.example.Browser",
                name: "Arc",
                configuration: settings.applicationProfileConfiguration
            )
        )
        editor.name = "Editor"
        settings.upsertApplicationProfile(editor)

        XCTAssertEqual(
            settings.applicationProfiles.map(\.bundleIdentifier),
            ["com.example.Browser", "com.example.Editor"]
        )
        XCTAssertEqual(
            settings.applicationProfiles[1].configuration.minimumStepDistance,
            ScrollStep.maximum
        )

        settings.removeApplicationProfile(bundleIdentifier: editor.bundleIdentifier)
        XCTAssertEqual(
            settings.applicationProfiles.map(\.bundleIdentifier),
            ["com.example.Browser"]
        )
    }

    func testInvalidPersistedProfileDataFallsBackToEmptyList() {
        defaults.set(Data("not-json".utf8), forKey: "scroll.applicationProfiles")
        XCTAssertTrue(makeSettings().applicationProfiles.isEmpty)
    }

    func testResetClearsProfilesWithoutChangingAppPreferences() {
        let settings = makeSettings()
        settings.showInMenuBar = false
        settings.upsertApplicationProfile(
            makeProfile(
                bundleIdentifier: "com.example.Browser",
                name: "Browser",
                configuration: settings.applicationProfileConfiguration
            )
        )

        settings.resetDefaults()

        XCTAssertTrue(settings.applicationProfiles.isEmpty)
        XCTAssertFalse(settings.showInMenuBar)
    }

    func testContextTrackerResetsOnlyWhenSelectedProfileChanges() {
        var tracker = ApplicationProfileContextTracker()

        XCTAssertFalse(tracker.shouldReset(for: nil))
        XCTAssertFalse(tracker.shouldReset(for: nil))
        XCTAssertTrue(tracker.shouldReset(for: "com.example.Browser"))
        XCTAssertFalse(tracker.shouldReset(for: "com.example.Browser"))
        XCTAssertTrue(tracker.shouldReset(for: "com.example.Editor"))
        XCTAssertTrue(tracker.shouldReset(for: nil))
        tracker.reset()
        XCTAssertFalse(tracker.shouldReset(for: "com.example.Browser"))
    }

    private func makeSettings() -> ScrollSettings {
        ScrollSettings(defaults: defaults, managesLaunchAtLogin: false)
    }

    private func makeProfile(
        bundleIdentifier: String,
        name: String,
        configuration: ApplicationScrollConfiguration
    ) -> ApplicationScrollProfile {
        ApplicationScrollProfile(
            bundleIdentifier: bundleIdentifier,
            name: name,
            isEnabled: true,
            configuration: configuration
        )
    }
}
