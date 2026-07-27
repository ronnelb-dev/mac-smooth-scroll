import Foundation
import XCTest
@testable import MacSmoothScroll

final class SystemHealthTests: XCTestCase {
    func testHealthSnapshotMapsRuntimeSignals() {
        let healthy = SystemHealthSnapshot.make(
            permissionGranted: true,
            engine: .active,
            competingDriverRunning: false,
            launchAtLogin: .enabled
        )

        XCTAssertEqual(healthy.accessibility, .ready)
        XCTAssertEqual(healthy.engine, .active)
        XCTAssertEqual(healthy.competingDriver, .clear)
        XCTAssertEqual(healthy.launchAtLogin, .enabled)

        let blocked = SystemHealthSnapshot.make(
            permissionGranted: false,
            engine: .permissionBlocked,
            competingDriverRunning: true,
            launchAtLogin: .approvalRequired
        )

        XCTAssertEqual(blocked.accessibility, .permissionRequired)
        XCTAssertEqual(blocked.engine, .permissionBlocked)
        XCTAssertEqual(blocked.competingDriver, .detected)
        XCTAssertEqual(blocked.launchAtLogin, .approvalRequired)
    }

    func testEveryEngineStatusHasAConciseHeaderMessage() {
        let statuses: [ScrollEngineStatus] = [
            .waiting,
            .active,
            .disabled,
            .permissionBlocked,
            .driverConflict,
            .startFailed
        ]

        XCTAssertEqual(Set(statuses.map(\.message)).count, statuses.count)
        XCTAssertTrue(statuses.allSatisfy { !$0.message.isEmpty })
    }

    func testDisabledLaunchAtLoginIsAnExplicitNeutralStatus() {
        XCTAssertEqual(LaunchAtLoginHealthStatus.disabled.rawValue, "Off")
    }

    func testLaunchAtLoginStatusesChooseTheExpectedRecovery() {
        XCTAssertEqual(LaunchAtLoginHealthStatus.disabled.recovery, .none)
        XCTAssertEqual(LaunchAtLoginHealthStatus.enabled.recovery, .none)
        XCTAssertEqual(LaunchAtLoginHealthStatus.approvalRequired.recovery, .openSettings)
        XCTAssertEqual(LaunchAtLoginHealthStatus.registrationMissing.recovery, .repair)
        XCTAssertEqual(LaunchAtLoginHealthStatus.helperMissing.recovery, .openApplications)
        XCTAssertEqual(LaunchAtLoginHealthStatus.unavailable.recovery, .openSettings)
    }

    func testDiagnosticsReportContainsOnlyApprovedStatusFields() {
        let diagnostics = SystemDiagnostics(
            appVersion: "0.3.1",
            appBuild: "4",
            macOSVersion: "Version 15.5 (Build 24F74)",
            architecture: "arm64",
            smoothScrollingEnabled: true,
            accessibility: .ready,
            engine: .active,
            competingDriver: .clear,
            showInMenuBar: true,
            launchAtLoginEnabled: false,
            launchAtLogin: .disabled
        )

        XCTAssertEqual(
            diagnostics.report,
            """
            Mac Smooth Scroll Diagnostics
            App: 0.3.1 (4)
            macOS: Version 15.5 (Build 24F74)
            Architecture: arm64
            Smooth scrolling: On
            Accessibility: Ready
            Scroll engine: Active
            Mouse driver conflict: No conflict
            Show in menu bar: On
            Launch at login preference: Off
            Login helper: Off
            """
        )
        XCTAssertFalse(diagnostics.report.contains("/Users/"))
        XCTAssertFalse(diagnostics.report.localizedCaseInsensitiveContains("certificate"))
        XCTAssertFalse(diagnostics.report.localizedCaseInsensitiveContains("mouse activity"))
    }

    func testRecoveryMethodsUseInjectedRuntimeCallbacks() {
        let suiteName = "SystemHealthTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = ScrollSettings(defaults: defaults, managesLaunchAtLogin: false)
        var refreshCount = 0
        var quitCount = 0
        settings.onRefreshRuntime = { refreshCount += 1 }
        settings.onQuitCompetingDriver = { quitCount += 1 }
        settings.competingDriverRecoveryMessage = "Old error"

        settings.retryEngine()
        settings.quitCompetingDriver()

        XCTAssertEqual(refreshCount, 1)
        XCTAssertEqual(quitCount, 1)
        XCTAssertNil(settings.competingDriverRecoveryMessage)
    }
}
