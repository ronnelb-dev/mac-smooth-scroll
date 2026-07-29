import Foundation

enum AccessibilityHealthStatus: String, Equatable {
    case ready = "Ready"
    case permissionRequired = "Permission required"
}

enum ScrollEngineStatus: String, Equatable {
    case waiting = "Waiting"
    case active = "Active"
    case recovering = "Recovering"
    case disabled = "Off"
    case permissionBlocked = "Permission blocked"
    case driverConflict = "Driver conflict"
    case startFailed = "Could not start"

    var message: String {
        switch self {
        case .waiting:
            "Waiting to start"
        case .active:
            "Smooth scrolling is active"
        case .recovering:
            "Restoring the scroll engine"
        case .disabled:
            "Smooth scrolling is off"
        case .permissionBlocked:
            "Permission required"
        case .driverConflict:
            "Paused while Mac Mouse Fix is running"
        case .startFailed:
            "Could not start. Verify Accessibility, then retry."
        }
    }
}

enum CompetingDriverHealthStatus: String, Equatable {
    case clear = "No conflict"
    case detected = "Mac Mouse Fix detected"
}

enum LaunchAtLoginHealthStatus: String, Equatable {
    case disabled = "Off"
    case enabled = "Ready"
    case approvalRequired = "Approval required"
    case registrationMissing = "Registration missing"
    case helperMissing = "Helper missing"
    case unavailable = "Unavailable"

    var recovery: LaunchAtLoginRecovery {
        switch self {
        case .disabled, .enabled:
            .none
        case .approvalRequired, .unavailable:
            .openSettings
        case .registrationMissing:
            .repair
        case .helperMissing:
            .openApplications
        }
    }
}

enum LaunchAtLoginRecovery: Equatable {
    case none
    case openSettings
    case repair
    case openApplications
}

struct SystemHealthSnapshot: Equatable {
    let accessibility: AccessibilityHealthStatus
    let engine: ScrollEngineStatus
    let competingDriver: CompetingDriverHealthStatus
    let launchAtLogin: LaunchAtLoginHealthStatus

    static func make(
        permissionGranted: Bool,
        engine: ScrollEngineStatus,
        competingDriverRunning: Bool,
        launchAtLogin: LaunchAtLoginHealthStatus
    ) -> SystemHealthSnapshot {
        SystemHealthSnapshot(
            accessibility: permissionGranted ? .ready : .permissionRequired,
            engine: engine,
            competingDriver: competingDriverRunning ? .detected : .clear,
            launchAtLogin: launchAtLogin
        )
    }
}

struct SystemDiagnostics: Equatable {
    let appVersion: String
    let appBuild: String
    let macOSVersion: String
    let architecture: String
    let smoothScrollingEnabled: Bool
    let accessibility: AccessibilityHealthStatus
    let engine: ScrollEngineStatus
    let competingDriver: CompetingDriverHealthStatus
    let showInMenuBar: Bool
    let launchAtLoginEnabled: Bool
    let launchAtLogin: LaunchAtLoginHealthStatus

    var report: String {
        [
            "Mac Smooth Scroll Diagnostics",
            "App: \(appVersion) (\(appBuild))",
            "macOS: \(macOSVersion)",
            "Architecture: \(architecture)",
            "Smooth scrolling: \(onOff(smoothScrollingEnabled))",
            "Accessibility: \(accessibility.rawValue)",
            "Scroll engine: \(engine.rawValue)",
            "Mouse driver conflict: \(competingDriver.rawValue)",
            "Show in menu bar: \(onOff(showInMenuBar))",
            "Launch at login preference: \(onOff(launchAtLoginEnabled))",
            "Login helper: \(launchAtLogin.rawValue)"
        ].joined(separator: "\n")
    }

    static var currentArchitecture: String {
#if arch(arm64)
        "arm64"
#elseif arch(x86_64)
        "x86_64"
#else
        "unknown"
#endif
    }

    private func onOff(_ value: Bool) -> String {
        value ? "On" : "Off"
    }
}
