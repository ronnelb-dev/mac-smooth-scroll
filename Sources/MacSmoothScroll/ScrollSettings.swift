import ApplicationServices
import AppKit
import Combine
import CoreGraphics
import Foundation
import ServiceManagement

enum Smoothness: String, CaseIterable, Codable, Identifiable {
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

enum ScrollSpeed: String, CaseIterable, Codable, Identifiable {
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

    static func effectiveMinimum(
        distance: Double,
        multiplier: MinimumStepMultiplier
    ) -> Double {
        sanitized(distance) * multiplier.value
    }

    static func formattedEffectiveMinimum(
        distance: Double,
        multiplier: MinimumStepMultiplier
    ) -> String {
        String(
            format: "%.2f",
            effectiveMinimum(distance: distance, multiplier: multiplier)
        )
    }
}

enum MinimumStepMultiplier: String, CaseIterable, Codable, Identifiable {
    case half = "half"
    case standard = "standard"
    case oneAndHalf = "oneAndHalf"
    case double = "double"
    case triple = "triple"

    var id: String { rawValue }

    var value: Double {
        switch self {
        case .half: 0.5
        case .standard: 1
        case .oneAndHalf: 1.5
        case .double: 2
        case .triple: 3
        }
    }

    var title: String {
        switch self {
        case .half: "0.5×"
        case .standard: "1×"
        case .oneAndHalf: "1.5×"
        case .double: "2×"
        case .triple: "3×"
        }
    }
}

enum ScrollFeel: String, CaseIterable, Codable, Identifiable {
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

enum SettingsChangeScope: Equatable {
    case scrollConfiguration
    case engineLifecycle
    case menuBarPresentation
    case menuBarVisibility
    case applicationPreference

    var refreshesScrollEngine: Bool {
        self == .engineLifecycle
    }

    var refreshesMenuBar: Bool {
        switch self {
        case .engineLifecycle, .menuBarPresentation, .menuBarVisibility:
            true
        case .scrollConfiguration, .applicationPreference:
            false
        }
    }
}

enum EventTapFeaturePolicy {
    static func shouldRun(
        smoothScrollingEnabled: Bool,
        backForwardButtonsEnabled: Bool
    ) -> Bool {
        smoothScrollingEnabled || backForwardButtonsEnabled
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
        static let minimumStepMultiplier = "scroll.minimumStepMultiplier"
        static let feel = "scroll.feel"
        static let trackpadSimulation = "scroll.trackpadSimulation"
        static let reverseDirection = "scroll.reverseDirection"
        static let adaptivePrecision = "scroll.adaptivePrecision"
        static let accelerationEnabled = "scroll.accelerationEnabled"
        static let longDistanceBoostEnabled = "scroll.longDistanceBoostEnabled"
        static let axisLockEnabled = "scroll.axisLockEnabled"
        static let horizontalModifier = "modifier.horizontal"
        static let zoomModifier = "modifier.zoom"
        static let zoomBehavior = "modifier.zoomBehavior"
        static let swiftModifier = "modifier.swift"
        static let preciseModifier = "modifier.precise"
        static let bypassModifier = "modifier.bypass"
        static let excludedApplications = "scroll.excludedApplications"
        static let applicationProfiles = "scroll.applicationProfiles"
        static let backForwardButtonsEnabled = "mouse.backForwardButtonsEnabled"
        static let showInMenuBar = "app.showInMenuBar"
        static let launchAtLogin = "app.launchAtLogin"
        static let launchAtLoginRegisteredBuild = "app.launchAtLoginRegisteredBuild"
        static let onboardingCompleted = "app.onboardingCompleted"
        static let selectedTab = "settings.selectedTab"
    }

    private let defaults: UserDefaults
    private let managesLaunchAtLogin: Bool
    private var wheelCalibrationSession: WheelCalibrationSession?
    var onChange: ((SettingsChangeScope) -> Void)?
    var onOpenSettings: (() -> Void)?
    var onHideApp: (() -> Void)?
    var onRefreshRuntime: (() -> Void)?
    var onRetryEngine: (() -> Void)?
    var onQuitCompetingDriver: (() -> Void)?
    var onEngineStatusChange: (() -> Void)?

    @Published var isEnabled: Bool {
        didSet { persist(Key.enabled, isEnabled, scope: .engineLifecycle) }
    }
    @Published var smoothness: Smoothness {
        didSet { persist(Key.smoothness, smoothness.rawValue) }
    }
    @Published var speed: ScrollSpeed {
        didSet { persist(Key.speed, speed.rawValue, scope: .menuBarPresentation) }
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
    @Published var minimumStepMultiplier: MinimumStepMultiplier {
        didSet {
            persist(Key.minimumStepMultiplier, minimumStepMultiplier.rawValue)
        }
    }
    @Published var feel: ScrollFeel {
        didSet { persist(Key.feel, feel.rawValue, scope: .menuBarPresentation) }
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
    @Published var accelerationEnabled: Bool {
        didSet { persist(Key.accelerationEnabled, accelerationEnabled) }
    }
    @Published var longDistanceBoostEnabled: Bool {
        didSet {
            persist(Key.longDistanceBoostEnabled, longDistanceBoostEnabled)
        }
    }
    @Published var axisLockEnabled: Bool {
        didSet { persist(Key.axisLockEnabled, axisLockEnabled) }
    }
    @Published var horizontalModifier: ModifierKey {
        didSet { persist(Key.horizontalModifier, horizontalModifier.rawValue) }
    }
    @Published var zoomModifier: ModifierKey {
        didSet { persist(Key.zoomModifier, zoomModifier.rawValue) }
    }
    @Published var zoomBehavior: ZoomBehavior {
        didSet { persist(Key.zoomBehavior, zoomBehavior.rawValue) }
    }
    @Published var swiftModifier: ModifierKey {
        didSet { persist(Key.swiftModifier, swiftModifier.rawValue) }
    }
    @Published var preciseModifier: ModifierKey {
        didSet { persist(Key.preciseModifier, preciseModifier.rawValue) }
    }
    @Published var bypassModifier: ModifierKey {
        didSet { persist(Key.bypassModifier, bypassModifier.rawValue) }
    }
    @Published private(set) var excludedApplications: [ExcludedApplication] {
        didSet {
            let encoded = try? JSONEncoder().encode(excludedApplications)
            persist(Key.excludedApplications, encoded ?? Data())
        }
    }
    @Published private(set) var applicationProfiles: [ApplicationScrollProfile] {
        didSet {
            let encoded = try? JSONEncoder().encode(applicationProfiles)
            persist(Key.applicationProfiles, encoded ?? Data())
        }
    }
    @Published var backForwardButtonsEnabled: Bool {
        didSet {
            persist(
                Key.backForwardButtonsEnabled,
                backForwardButtonsEnabled,
                scope: .engineLifecycle
            )
        }
    }
    @Published var showInMenuBar: Bool {
        didSet { persist(Key.showInMenuBar, showInMenuBar, scope: .menuBarVisibility) }
    }
    @Published var launchAtLogin: Bool {
        didSet {
            persist(Key.launchAtLogin, launchAtLogin, scope: .applicationPreference)
            if managesLaunchAtLogin {
                updateLaunchAtLogin()
            }
        }
    }
    @Published var permissionGranted = false
    @Published var competingDriverRunning = false
    @Published var advisoryMouseDriverNames: [String] = []
    @Published var engineStatus = ScrollEngineStatus.waiting {
        didSet {
            if engineStatus != oldValue {
                onEngineStatusChange?()
            }
        }
    }
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
    @Published private(set) var wheelCalibrationState = WheelCalibrationState.idle

    var engineMessage: String {
        engineStatus.message
    }

    var systemHealth: SystemHealthSnapshot {
        SystemHealthSnapshot.make(
            permissionGranted: permissionGranted,
            engine: engineStatus,
            competingDriverRunning: competingDriverRunning,
            advisoryMouseDriversDetected: !advisoryMouseDriverNames.isEmpty,
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
        minimumStepMultiplier =
            MinimumStepMultiplier(
                rawValue: defaults.string(forKey: Key.minimumStepMultiplier) ?? ""
            ) ?? .standard
        feel = ScrollFeel(rawValue: defaults.string(forKey: Key.feel) ?? "") ?? .balanced
        trackpadSimulation = defaults.object(forKey: Key.trackpadSimulation) as? Bool ?? true
        reverseDirection = defaults.object(forKey: Key.reverseDirection) as? Bool ?? false
        adaptivePrecision = defaults.object(forKey: Key.adaptivePrecision) as? Bool ?? true
        let storedAcceleration =
            defaults.object(forKey: Key.accelerationEnabled) as? Bool ?? true
        accelerationEnabled = storedAcceleration
        if let storedLongDistanceBoost =
            defaults.object(forKey: Key.longDistanceBoostEnabled) as? Bool {
            longDistanceBoostEnabled = storedLongDistanceBoost
        } else {
            // Before this preference existed, long-distance boosting followed
            // Scroll acceleration. Persist that state once, then let both
            // controls evolve independently.
            longDistanceBoostEnabled = storedAcceleration
            defaults.set(storedAcceleration, forKey: Key.longDistanceBoostEnabled)
        }
        axisLockEnabled =
            defaults.object(forKey: Key.axisLockEnabled) as? Bool ?? true
        horizontalModifier = ModifierKey(rawValue: defaults.string(forKey: Key.horizontalModifier) ?? "") ?? .shift
        zoomModifier = ModifierKey(rawValue: defaults.string(forKey: Key.zoomModifier) ?? "") ?? .command
        zoomBehavior =
            ZoomBehavior(rawValue: defaults.string(forKey: Key.zoomBehavior) ?? "")
            ?? .pinch
        swiftModifier = ModifierKey(rawValue: defaults.string(forKey: Key.swiftModifier) ?? "") ?? .control
        preciseModifier = ModifierKey(rawValue: defaults.string(forKey: Key.preciseModifier) ?? "") ?? .option
        bypassModifier =
            ModifierKey(rawValue: defaults.string(forKey: Key.bypassModifier) ?? "")
            ?? .none
        let storedExcludedApplications = defaults.data(forKey: Key.excludedApplications)
        excludedApplications =
            storedExcludedApplications
                .flatMap { try? JSONDecoder().decode([ExcludedApplication].self, from: $0) }
            ?? []
        let storedApplicationProfiles = defaults.data(forKey: Key.applicationProfiles)
        applicationProfiles =
            storedApplicationProfiles
                .flatMap {
                    try? JSONDecoder().decode(
                        [ApplicationScrollProfile].self,
                        from: $0
                    )
                }
            ?? []
        backForwardButtonsEnabled =
            defaults.object(forKey: Key.backForwardButtonsEnabled) as? Bool
            ?? true
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
        if let onRetryEngine {
            onRetryEngine()
        } else {
            recheckRuntime()
        }
    }

    func recheckRuntime() {
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
        cancelWheelCalibration()
        isEnabled = true
        smoothness = .high
        speed = .medium
        minimumStepEnabled = true
        minimumStepDistance = ScrollStep.defaultValue
        minimumStepMultiplier = .standard
        feel = .balanced
        trackpadSimulation = true
        reverseDirection = false
        adaptivePrecision = true
        accelerationEnabled = true
        longDistanceBoostEnabled = true
        axisLockEnabled = true
        horizontalModifier = .shift
        zoomModifier = .command
        zoomBehavior = .pinch
        swiftModifier = .control
        preciseModifier = .option
        bypassModifier = .none
        excludedApplications = []
        applicationProfiles = []
        backForwardButtonsEnabled = true
    }

    func resetMinimumStepDistance() {
        minimumStepEnabled = true
        minimumStepDistance = ScrollStep.defaultValue
        minimumStepMultiplier = .standard
    }

    func startWheelCalibration() {
        wheelCalibrationSession = WheelCalibrationSession()
        wheelCalibrationState = .collecting(sampleCount: 0)
    }

    func cancelWheelCalibration() {
        wheelCalibrationSession = nil
        wheelCalibrationState = .idle
    }

    func finishWheelCalibration() {
        guard let session = wheelCalibrationSession else { return }
        wheelCalibrationSession = nil
        wheelCalibrationState = .result(session.finish())
    }

    func recordWheelCalibrationSample(_ sample: WheelCalibrationSample) {
        guard var session = wheelCalibrationSession else { return }
        if let result = session.record(sample) {
            wheelCalibrationSession = nil
            wheelCalibrationState = .result(result)
        } else {
            wheelCalibrationSession = session
            wheelCalibrationState = .collecting(sampleCount: session.sampleCount)
        }
    }

    func applyWheelCalibrationRecommendation() {
        guard case let .result(result) = wheelCalibrationState,
              let recommendation = result.recommendation
        else {
            return
        }

        minimumStepEnabled = recommendation.minimumStepEnabled
        if let distance = recommendation.minimumStepDistance {
            minimumStepDistance = distance
        }
        if let multiplier = recommendation.minimumStepMultiplier {
            minimumStepMultiplier = multiplier
        }
        wheelCalibrationState = .idle
    }

    func addExcludedApplication(at url: URL) throws {
        addExcludedApplication(try ExcludedApplication.resolve(at: url))
    }

    func addExcludedApplication(_ application: ExcludedApplication) {
        guard !excludedApplications.contains(where: {
            $0.bundleIdentifier == application.bundleIdentifier
        }) else {
            return
        }

        excludedApplications.append(application)
        excludedApplications.sort {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    func removeExcludedApplication(bundleIdentifier: String) {
        excludedApplications.removeAll {
            $0.bundleIdentifier == bundleIdentifier
        }
    }

    var excludedApplicationBundleIdentifiers: Set<String> {
        Set(excludedApplications.map(\.bundleIdentifier))
    }

    func applicationProfile(at url: URL) throws -> ApplicationScrollProfile {
        let application = try ExcludedApplication.resolve(at: url)
        if let existing = applicationProfiles.first(where: {
            $0.bundleIdentifier == application.bundleIdentifier
        }) {
            return existing
        }

        let profile = ApplicationScrollProfile(
            bundleIdentifier: application.bundleIdentifier,
            name: application.name,
            isEnabled: true,
            configuration: applicationProfileConfiguration
        )
        return profile
    }

    func upsertApplicationProfile(_ profile: ApplicationScrollProfile) {
        applicationProfiles.removeAll {
            $0.bundleIdentifier == profile.bundleIdentifier
        }
        applicationProfiles.append(profile.sanitized)
        applicationProfiles.sort {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    func setApplicationProfileEnabled(
        _ enabled: Bool,
        bundleIdentifier: String
    ) {
        guard let index = applicationProfiles.firstIndex(where: {
            $0.bundleIdentifier == bundleIdentifier
        }) else { return }
        applicationProfiles[index].isEnabled = enabled
    }

    func removeApplicationProfile(bundleIdentifier: String) {
        applicationProfiles.removeAll {
            $0.bundleIdentifier == bundleIdentifier
        }
    }

    func runtimeConfiguration(
        for bundleIdentifier: String?
    ) -> ResolvedScrollRuntimeConfiguration {
        let profile = bundleIdentifier.flatMap { identifier in
            applicationProfiles.first {
                $0.isEnabled && $0.bundleIdentifier == identifier
            }
        }
        let scrolling = profile?.configuration ?? applicationProfileConfiguration
        return ResolvedScrollRuntimeConfiguration(
            profileBundleIdentifier: profile?.bundleIdentifier,
            transform: scrolling.transformConfiguration(
                horizontalModifier: horizontalModifier,
                zoomModifier: zoomModifier,
                zoomBehavior: zoomBehavior,
                swiftModifier: swiftModifier,
                preciseModifier: preciseModifier
            ),
            smoothness: scrolling.smoothness,
            feel: scrolling.feel,
            trackpadSimulation: scrolling.trackpadSimulation
        )
    }

    var applicationProfileConfiguration: ApplicationScrollConfiguration {
        ApplicationScrollConfiguration(
            smoothness: smoothness,
            speed: speed,
            minimumStepEnabled: minimumStepEnabled,
            minimumStepDistance: minimumStepDistance,
            minimumStepMultiplier: minimumStepMultiplier,
            feel: feel,
            trackpadSimulation: trackpadSimulation,
            reverseDirection: reverseDirection,
            adaptivePrecision: adaptivePrecision,
            accelerationEnabled: accelerationEnabled,
            longDistanceBoostEnabled: longDistanceBoostEnabled,
            axisLockEnabled: axisLockEnabled
        )
    }

    private func persist(
        _ key: String,
        _ value: Any,
        scope: SettingsChangeScope = .scrollConfiguration
    ) {
        defaults.set(value, forKey: key)
        onChange?(scope)
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
