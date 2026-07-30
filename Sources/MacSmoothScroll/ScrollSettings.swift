import ApplicationServices
import AppKit
import Combine
import CoreGraphics
import Foundation
import ServiceManagement

enum Smoothness: String, CaseIterable, Identifiable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var id: String { rawValue }

    var decay: Double {
        switch self {
        case .low: 0.80
        case .medium: 0.88
        case .high: 0.93
        }
    }
}

enum ScrollSpeed: String, CaseIterable, Identifiable {
    case slow = "Slow"
    case medium = "Medium"
    case fast = "Fast"

    var id: String { rawValue }

    var multiplier: Double {
        switch self {
        case .slow: 0.72
        case .medium: 1.0
        case .fast: 1.45
        }
    }
}

enum ScrollStep {
    static let defaultValue = 18.0
    static let minimum = 0.01
    static let maximum = 100.0
    static let increment = 0.01
    static let range = minimum...maximum

    static func sanitized(_ value: Double) -> Double {
        guard value.isFinite else { return defaultValue }
        let clamped = min(max(value, minimum), maximum)
        return (clamped / increment).rounded() * increment
    }

    static func adjusted(_ value: Double, bySteps steps: Int) -> Double {
        sanitized(value + (Double(steps) * increment))
    }

    static func formatted(_ value: Double) -> String {
        String(format: "%.2f", sanitized(value))
    }
}

enum ScrollFeel: String, CaseIterable, Identifiable {
    case responsive = "Responsive"
    case balanced = "Balanced"
    case glide = "Glide"

    var id: String { rawValue }

    var maximumVelocity: Double {
        switch self {
        case .responsive: 18
        case .balanced: 24
        case .glide: 30
        }
    }

    var rapidInputBoost: Double {
        switch self {
        case .responsive: 0.12
        case .balanced: 0.22
        case .glide: 0.30
        }
    }

    var directionChangeRetention: Double {
        switch self {
        case .responsive: 0
        case .balanced: 0.08
        case .glide: 0.16
        }
    }
}

enum ModifierKey: String, CaseIterable, Identifiable {
    case shift
    case command
    case control
    case option
    case none

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shift: "Shift"
        case .command: "Command"
        case .control: "Control"
        case .option: "Option"
        case .none: "None"
        }
    }

    var symbol: String {
        switch self {
        case .shift: "⇧"
        case .command: "⌘"
        case .control: "⌃"
        case .option: "⌥"
        case .none: "—"
        }
    }

    var flag: CGEventFlags {
        switch self {
        case .shift: .maskShift
        case .command: .maskCommand
        case .control: .maskControl
        case .option: .maskAlternate
        case .none: []
        }
    }

    func isActive(in flags: CGEventFlags) -> Bool {
        self != .none && flags.contains(flag)
    }
}

final class ScrollSettings: ObservableObject {
    static let launcherBundleIdentifier = "com.ronnel.mac-smooth-scroll.launcher"

    private enum Key {
        static let enabled = "scroll.enabled"
        static let smoothness = "scroll.smoothness"
        static let speed = "scroll.speed"
        static let minimumStepEnabled = "scroll.minimumStepEnabled"
        static let minimumStepDistance = "scroll.step"
        static let feel = "scroll.feel"
        static let trackpadSimulation = "scroll.trackpadSimulation"
        static let reverseDirection = "scroll.reverseDirection"
        static let adaptivePrecision = "scroll.adaptivePrecision"
        static let horizontalModifier = "modifier.horizontal"
        static let zoomModifier = "modifier.zoom"
        static let swiftModifier = "modifier.swift"
        static let preciseModifier = "modifier.precise"
        static let showInMenuBar = "app.showInMenuBar"
        static let launchAtLogin = "app.launchAtLogin"
        static let launchAtLoginRegisteredBuild = "app.launchAtLoginRegisteredBuild"
        static let onboardingCompleted = "app.onboardingCompleted"
        static let selectedTab = "settings.selectedTab"
    }

    private let defaults: UserDefaults
    private let managesLaunchAtLogin: Bool
    var onChange: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onHideApp: (() -> Void)?
    var onRefreshRuntime: (() -> Void)?
    var onQuitCompetingDriver: (() -> Void)?

    @Published var isEnabled: Bool {
        didSet { persist(Key.enabled, isEnabled) }
    }
    @Published var smoothness: Smoothness {
        didSet { persist(Key.smoothness, smoothness.rawValue) }
    }
    @Published var speed: ScrollSpeed {
        didSet { persist(Key.speed, speed.rawValue) }
    }
    @Published var minimumStepEnabled: Bool {
        didSet { persist(Key.minimumStepEnabled, minimumStepEnabled) }
    }
    @Published var minimumStepDistance: Double {
        didSet {
            let sanitizedValue = ScrollStep.sanitized(minimumStepDistance)
            guard minimumStepDistance == sanitizedValue else {
                minimumStepDistance = sanitizedValue
                return
            }
            persist(Key.minimumStepDistance, minimumStepDistance)
        }
    }
    @Published var feel: ScrollFeel {
        didSet { persist(Key.feel, feel.rawValue) }
    }
    @Published var trackpadSimulation: Bool {
        didSet { persist(Key.trackpadSimulation, trackpadSimulation) }
    }
    @Published var reverseDirection: Bool {
        didSet { persist(Key.reverseDirection, reverseDirection) }
    }
    @Published var adaptivePrecision: Bool {
        didSet { persist(Key.adaptivePrecision, adaptivePrecision) }
    }
    @Published var horizontalModifier: ModifierKey {
        didSet { persist(Key.horizontalModifier, horizontalModifier.rawValue) }
    }
    @Published var zoomModifier: ModifierKey {
        didSet { persist(Key.zoomModifier, zoomModifier.rawValue) }
    }
    @Published var swiftModifier: ModifierKey {
        didSet { persist(Key.swiftModifier, swiftModifier.rawValue) }
    }
    @Published var preciseModifier: ModifierKey {
        didSet { persist(Key.preciseModifier, preciseModifier.rawValue) }
    }
    @Published var showInMenuBar: Bool {
        didSet { persist(Key.showInMenuBar, showInMenuBar) }
    }
    @Published var launchAtLogin: Bool {
        didSet {
            persist(Key.launchAtLogin, launchAtLogin)
            if managesLaunchAtLogin {
                updateLaunchAtLogin()
            }
        }
    }
    @Published var permissionGranted = false
    @Published var competingDriverRunning = false
    @Published var engineStatus = ScrollEngineStatus.waiting
    @Published var launchAtLoginHealthStatus = LaunchAtLoginHealthStatus.unavailable
    @Published var launchAtLoginDetail = "Checking login item status…"
    @Published var competingDriverRecoveryMessage: String?
    @Published private(set) var onboardingCompleted: Bool
    @Published var isSetupPresented = false
    @Published var selectedTab: SettingsTab {
        didSet {
            defaults.set(selectedTab.rawValue, forKey: Key.selectedTab)
        }
    }

    var engineMessage: String {
        engineStatus.message
    }

    var systemHealth: SystemHealthSnapshot {
        SystemHealthSnapshot.make(
            permissionGranted: permissionGranted,
            engine: engineStatus,
            competingDriverRunning: competingDriverRunning,
            launchAtLogin: launchAtLoginHealthStatus
        )
    }

    init(
        defaults: UserDefaults = .standard,
        managesLaunchAtLogin: Bool = true
    ) {
        self.defaults = defaults
        self.managesLaunchAtLogin = managesLaunchAtLogin
        isEnabled = defaults.object(forKey: Key.enabled) as? Bool ?? true
        smoothness = Smoothness(rawValue: defaults.string(forKey: Key.smoothness) ?? "") ?? .high
        speed = ScrollSpeed(rawValue: defaults.string(forKey: Key.speed) ?? "") ?? .medium
        minimumStepEnabled =
            defaults.object(forKey: Key.minimumStepEnabled) as? Bool ?? true
        let storedStep = (defaults.object(forKey: Key.minimumStepDistance) as? NSNumber)?.doubleValue
        minimumStepDistance = ScrollStep.sanitized(storedStep ?? ScrollStep.defaultValue)
        feel = ScrollFeel(rawValue: defaults.string(forKey: Key.feel) ?? "") ?? .balanced
        trackpadSimulation = defaults.object(forKey: Key.trackpadSimulation) as? Bool ?? true
        reverseDirection = defaults.object(forKey: Key.reverseDirection) as? Bool ?? false
        adaptivePrecision = defaults.object(forKey: Key.adaptivePrecision) as? Bool ?? true
        horizontalModifier = ModifierKey(rawValue: defaults.string(forKey: Key.horizontalModifier) ?? "") ?? .shift
        zoomModifier = ModifierKey(rawValue: defaults.string(forKey: Key.zoomModifier) ?? "") ?? .command
        swiftModifier = ModifierKey(rawValue: defaults.string(forKey: Key.swiftModifier) ?? "") ?? .control
        preciseModifier = ModifierKey(rawValue: defaults.string(forKey: Key.preciseModifier) ?? "") ?? .option
        showInMenuBar = defaults.object(forKey: Key.showInMenuBar) as? Bool ?? true
        launchAtLogin = defaults.object(forKey: Key.launchAtLogin) as? Bool ?? false
        onboardingCompleted = defaults.bool(forKey: Key.onboardingCompleted)
        selectedTab = SettingsTab.resolve(defaults.string(forKey: Key.selectedTab))
        launchAtLoginHealthStatus = launchAtLogin ? .unavailable : .disabled
    }

    var isInstalledInApplications: Bool {
        FirstRunSetup.isInstalledInApplications(Bundle.main.bundleURL)
    }

    func presentInitialSetupIfNeeded() {
        guard !onboardingCompleted else { return }
        isSetupPresented = true
    }

    func presentSetup() {
        isSetupPresented = true
    }

    func dismissSetup() {
        isSetupPresented = false
    }

    func completeSetup() {
        onboardingCompleted = true
        defaults.set(true, forKey: Key.onboardingCompleted)
        isSetupPresented = false
    }

    func requestPermissions() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
    }

    func openPrivacySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    func openApplicationsFolder() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications", isDirectory: true))
    }

    func hideToMenuBar() {
        onHideApp?()
    }

    func retryEngine() {
        onRefreshRuntime?()
    }

    func quitCompetingDriver() {
        competingDriverRecoveryMessage = nil
        onQuitCompetingDriver?()
    }

    func migrateLaunchAtLoginRegistration() {
        guard managesLaunchAtLogin else { return }
        let legacyService = SMAppService.mainApp
        if legacyService.status == .enabled || legacyService.status == .requiresApproval {
            try? legacyService.unregister()
        }

        let launcherService = SMAppService.loginItem(identifier: Self.launcherBundleIdentifier)
        let registeredBuild = defaults.string(forKey: Key.launchAtLoginRegisteredBuild)
        let currentBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        if launchAtLogin,
           launcherService.status == .enabled,
           registeredBuild != currentBuild {
            try? launcherService.unregister()
        }

        updateLaunchAtLogin()
    }

    func refreshLaunchAtLoginStatus() {
        guard managesLaunchAtLogin else { return }
        guard #available(macOS 13.0, *) else {
            launchAtLoginHealthStatus = .unavailable
            launchAtLoginDetail = "Requires macOS 13 or later."
            return
        }

        let launcherService = SMAppService.loginItem(identifier: Self.launcherBundleIdentifier)
        switch launcherService.status {
        case .enabled:
            launchAtLoginHealthStatus = .enabled
            launchAtLoginDetail = "Starts hidden in the menu bar after login."
        case .requiresApproval:
            launchAtLoginHealthStatus = .approvalRequired
            launchAtLoginDetail = "Allow Mac Smooth Scroll in System Settings → General → Login Items."
        case .notRegistered:
            launchAtLoginHealthStatus = launchAtLogin ? .registrationMissing : .disabled
            launchAtLoginDetail = launchAtLogin
                ? "macOS does not currently have the login helper registered."
                : "Launch at login is disabled."
        case .notFound:
            launchAtLoginHealthStatus = .helperMissing
            launchAtLoginDetail =
                "Install Mac Smooth Scroll in Applications, reopen it, and enable Launch at login again."
        @unknown default:
            launchAtLoginHealthStatus = .unavailable
            launchAtLoginDetail = "Open Login Items Settings to verify the current permission."
        }
    }

    func repairLaunchAtLogin() {
        guard managesLaunchAtLogin, launchAtLogin else { return }
        guard #available(macOS 13.0, *) else {
            refreshLaunchAtLoginStatus()
            return
        }

        let launcherService = SMAppService.loginItem(identifier: Self.launcherBundleIdentifier)
        do {
            if launcherService.status == .enabled || launcherService.status == .requiresApproval {
                try launcherService.unregister()
            }
            try launcherService.register()
            defaults.set(
                Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
                forKey: Key.launchAtLoginRegisteredBuild
            )
            refreshLaunchAtLoginStatus()
        } catch {
            launchAtLoginHealthStatus = .unavailable
            launchAtLoginDetail = "Launch at login could not be repaired: \(error.localizedDescription)"
        }
    }

    func resetDefaults() {
        isEnabled = true
        smoothness = .high
        speed = .medium
        minimumStepEnabled = true
        minimumStepDistance = ScrollStep.defaultValue
        feel = .balanced
        trackpadSimulation = true
        reverseDirection = false
        adaptivePrecision = true
        horizontalModifier = .shift
        zoomModifier = .command
        swiftModifier = .control
        preciseModifier = .option
    }

    func resetMinimumStepDistance() {
        minimumStepEnabled = true
        minimumStepDistance = ScrollStep.defaultValue
    }

    private func persist(_ key: String, _ value: Any) {
        defaults.set(value, forKey: key)
        onChange?()
    }

    private func updateLaunchAtLogin() {
        guard #available(macOS 13.0, *) else { return }
        let launcherService = SMAppService.loginItem(identifier: Self.launcherBundleIdentifier)
        let legacyService = SMAppService.mainApp

        do {
            if launchAtLogin {
                if legacyService.status == .enabled || legacyService.status == .requiresApproval {
                    try? legacyService.unregister()
                }
                if launcherService.status == .notRegistered || launcherService.status == .notFound {
                    try launcherService.register()
                }
            } else {
                if launcherService.status == .enabled || launcherService.status == .requiresApproval {
                    try? launcherService.unregister()
                }
                if legacyService.status == .enabled || legacyService.status == .requiresApproval {
                    try? legacyService.unregister()
                }
            }
            refreshLaunchAtLoginStatus()
            if launchAtLogin,
               launcherService.status == .enabled || launcherService.status == .requiresApproval {
                defaults.set(
                    Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
                    forKey: Key.launchAtLoginRegisteredBuild
                )
            } else if !launchAtLogin {
                defaults.removeObject(forKey: Key.launchAtLoginRegisteredBuild)
            }
        } catch {
            launchAtLoginHealthStatus = .unavailable
            launchAtLoginDetail = "Launch at login could not be changed: \(error.localizedDescription)"
        }
    }
}
