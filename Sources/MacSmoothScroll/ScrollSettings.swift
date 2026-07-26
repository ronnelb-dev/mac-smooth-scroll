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
    }

    private let defaults: UserDefaults
    private let managesLaunchAtLogin: Bool
    var onChange: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onHideApp: (() -> Void)?

    @Published var isEnabled: Bool {
        didSet { persist(Key.enabled, isEnabled) }
    }
    @Published var smoothness: Smoothness {
        didSet { persist(Key.smoothness, smoothness.rawValue) }
    }
    @Published var speed: ScrollSpeed {
        didSet { persist(Key.speed, speed.rawValue) }
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
    @Published var engineMessage = "Waiting to start"
    @Published var launchAtLoginMessage: String?

    init(
        defaults: UserDefaults = .standard,
        managesLaunchAtLogin: Bool = true
    ) {
        self.defaults = defaults
        self.managesLaunchAtLogin = managesLaunchAtLogin
        isEnabled = defaults.object(forKey: Key.enabled) as? Bool ?? true
        smoothness = Smoothness(rawValue: defaults.string(forKey: Key.smoothness) ?? "") ?? .high
        speed = ScrollSpeed(rawValue: defaults.string(forKey: Key.speed) ?? "") ?? .medium
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
    }

    func requestPermissions() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
        engineMessage = "Approve Mac Smooth Scroll under Accessibility, then return here."
    }

    func openPrivacySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    func hideToMenuBar() {
        onHideApp?()
    }

    func migrateLaunchAtLoginRegistration() {
        guard managesLaunchAtLogin else { return }
        let legacyService = SMAppService.mainApp
        if legacyService.status == .enabled || legacyService.status == .requiresApproval {
            try? legacyService.unregister()
        }
        updateLaunchAtLogin()
    }

    func resetDefaults() {
        isEnabled = true
        smoothness = .high
        speed = .medium
        feel = .balanced
        trackpadSimulation = true
        reverseDirection = false
        adaptivePrecision = true
        horizontalModifier = .shift
        zoomModifier = .command
        swiftModifier = .control
        preciseModifier = .option
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
                launchAtLoginMessage = launcherService.status == .requiresApproval
                    ? "Approve Mac Smooth Scroll under System Settings → General → Login Items."
                    : nil
            } else {
                if launcherService.status == .enabled || launcherService.status == .requiresApproval {
                    try? launcherService.unregister()
                }
                if legacyService.status == .enabled || legacyService.status == .requiresApproval {
                    try? legacyService.unregister()
                }
                launchAtLoginMessage = nil
            }
        } catch {
            launchAtLoginMessage = "Launch at login could not be changed: \(error.localizedDescription)"
        }
    }
}
