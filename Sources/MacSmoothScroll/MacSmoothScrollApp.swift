import AppKit
import ServiceManagement
import SwiftUI

@main
struct MacSmoothScrollApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("Mac Smooth Scroll", id: "settings") {
            SettingsView()
                .environmentObject(appDelegate.settings)
                .frame(minWidth: 640, idealWidth: 680, minHeight: 520, idealHeight: 560)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 680, height: 560)
        .defaultPosition(.center)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    let settings = ScrollSettings()
    private lazy var scrollEngine = SmoothScrollEngine(settings: settings)
    private var statusItem: NSStatusItem?
    private var permissionTimer: Timer?
    private var isHiddenToMenuBar = false
    private var isTerminating = false
    private let launchMode = AppLaunchMode(arguments: ProcessInfo.processInfo.arguments)

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(launchMode == .background ? .accessory : .regular)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        settings.onChange = { [weak self] in
            self?.settingsDidChange()
        }
        settings.onOpenSettings = { [weak self] in
            self?.showSettings()
        }
        settings.onHideApp = { [weak self] in
            self?.hideToMenuBar()
        }
        settings.onRefreshRuntime = { [weak self] in
            self?.updateRuntimeState(forceEngineRefresh: true)
        }
        settings.onQuitCompetingDriver = { [weak self] in
            self?.quitCompetingDriver()
        }

        updateRuntimeState()
        scrollEngine.refresh()
        configureStatusItem()
        settings.migrateLaunchAtLoginRegistration()

        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.updateRuntimeState()
        }
        RunLoop.main.add(permissionTimer!, forMode: .common)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.attachWindowDelegates()
            if self.launchMode == .background {
                self.hideToMenuBar()
            } else {
                self.showSettings()
                self.settings.presentInitialSetupIfNeeded()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        isTerminating = true
        permissionTimer?.invalidate()
        scrollEngine.stop()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        settings.refreshLaunchAtLoginStatus()
    }

    func applicationDidHide(_ notification: Notification) {
        guard !isTerminating else { return }
        hideToMenuBar()
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        showSettings()
        return true
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard !isTerminating else { return true }
        hideToMenuBar()
        return false
    }

    private func settingsDidChange() {
        scrollEngine.refresh()
        configureStatusItem()
    }

    private func updateRuntimeState(forceEngineRefresh: Bool = false) {
        let wasGranted = settings.permissionGranted
        let wasCompetitorRunning = settings.competingDriverRunning
        // A modifying CGEvent tap is authorized through Accessibility. The
        // Input Monitoring preflight API is for listen-only monitoring and
        // should not block this app after Accessibility has been granted.
        settings.permissionGranted = AXIsProcessTrusted()
        settings.competingDriverRunning =
            !NSRunningApplication.runningApplications(withBundleIdentifier: "com.nuebling.mac-mouse-fix").isEmpty ||
            !NSRunningApplication.runningApplications(withBundleIdentifier: "com.nuebling.mac-mouse-fix.helper").isEmpty
        if !settings.competingDriverRunning {
            settings.competingDriverRecoveryMessage = nil
        }

        if forceEngineRefresh ||
            settings.permissionGranted != wasGranted ||
            settings.competingDriverRunning != wasCompetitorRunning {
            scrollEngine.refresh()
            updateStatusItemAppearance()
        } else {
            let previousEngineStatus = settings.engineStatus
            scrollEngine.auditHealth()
            if settings.engineStatus != previousEngineStatus {
                updateStatusItemAppearance()
            }
        }
    }

    private func quitCompetingDriver() {
        let bundleIdentifiers = [
            "com.nuebling.mac-mouse-fix",
            "com.nuebling.mac-mouse-fix.helper"
        ]
        let applications = bundleIdentifiers.flatMap {
            NSRunningApplication.runningApplications(withBundleIdentifier: $0)
        }
        let accepted = applications.reduce(false) { result, application in
            application.terminate() || result
        }

        if !applications.isEmpty && !accepted {
            settings.competingDriverRecoveryMessage =
                "Mac Mouse Fix could not be quit automatically. Quit it from its menu, then retry."
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self] in
            self?.updateRuntimeState(forceEngineRefresh: true)
            if self?.settings.competingDriverRunning == true {
                self?.settings.competingDriverRecoveryMessage =
                    "Mac Mouse Fix is still running. Quit it from its menu, then retry."
            }
        }
    }

    private func configureStatusItem() {
        guard settings.showInMenuBar else {
            if let statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
                self.statusItem = nil
            }
            return
        }

        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        }

        updateStatusItemAppearance()
        rebuildStatusMenu()
    }

    private func updateStatusItemAppearance() {
        guard let button = statusItem?.button else { return }
        let presentation = currentMenuBarPresentation
        button.image = symbolImage(
            presentation.statusItemSymbolName,
            accessibilityDescription: presentation.statusItemAccessibilityLabel
        )
        button.image?.isTemplate = true
        button.toolTip = presentation.statusItemAccessibilityLabel
        button.setAccessibilityLabel(presentation.statusItemAccessibilityLabel)
    }

    private var currentMenuBarPresentation: MenuBarPresentation {
        MenuBarPresentation.make(
            isEnabled: settings.isEnabled,
            engineStatus: settings.engineStatus
        )
    }

    private func rebuildStatusMenu(_ existingMenu: NSMenu? = nil) {
        guard statusItem != nil else { return }
        let presentation = currentMenuBarPresentation
        let menu = existingMenu ?? NSMenu()
        menu.removeAllItems()
        menu.delegate = self

        let status = NSMenuItem(
            title: presentation.statusTitle,
            action: nil,
            keyEquivalent: ""
        )
        status.image = symbolImage(presentation.statusSymbolName)
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        let toggle = NSMenuItem(
            title: "Smooth Scrolling",
            action: #selector(toggleScrolling),
            keyEquivalent: ""
        )
        toggle.target = self
        toggle.state = presentation.smoothScrollingIsOn ? .on : .off
        menu.addItem(toggle)

        menu.addItem(makeFeelMenu())
        menu.addItem(makeSpeedMenu())

        if let recoveryItem = makeRecoveryItem(for: presentation.recoveryAction) {
            menu.addItem(.separator())
            menu.addItem(recoveryItem)
        }

        menu.addItem(.separator())

        let open = NSMenuItem(
            title: "Open Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        open.target = self
        menu.addItem(open)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Quit Mac Smooth Scroll",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)
        statusItem?.menu = menu
    }

    private func makeFeelMenu() -> NSMenuItem {
        let parent = NSMenuItem(
            title: "Feel: \(settings.feel.rawValue)",
            action: nil,
            keyEquivalent: ""
        )
        let submenu = NSMenu(title: "Feel")
        for feel in ScrollFeel.allCases {
            let item = NSMenuItem(
                title: feel.rawValue,
                action: #selector(selectFeel(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = feel.rawValue
            item.state = settings.feel == feel ? .on : .off
            submenu.addItem(item)
        }
        parent.submenu = submenu
        return parent
    }

    private func makeSpeedMenu() -> NSMenuItem {
        let parent = NSMenuItem(
            title: "Speed: \(settings.speed.rawValue)",
            action: nil,
            keyEquivalent: ""
        )
        let submenu = NSMenu(title: "Speed")
        for speed in ScrollSpeed.allCases {
            let item = NSMenuItem(
                title: speed.rawValue,
                action: #selector(selectSpeed(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = speed.rawValue
            item.state = settings.speed == speed ? .on : .off
            submenu.addItem(item)
        }
        parent.submenu = submenu
        return parent
    }

    private func makeRecoveryItem(
        for recovery: MenuBarRecoveryAction
    ) -> NSMenuItem? {
        guard let title = recovery.title else { return nil }
        let selector: Selector
        let symbolName: String
        switch recovery {
        case .none:
            return nil
        case .openAccessibilitySettings:
            selector = #selector(openAccessibilitySettings)
            symbolName = "hand.raised"
        case .quitMacMouseFix:
            selector = #selector(quitMacMouseFixFromMenu)
            symbolName = "exclamationmark.triangle"
        case .retryEngine:
            selector = #selector(retryEngineFromMenu)
            symbolName = "arrow.clockwise"
        }

        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        item.image = symbolImage(symbolName)
        return item
    }

    private func symbolImage(
        _ name: String,
        accessibilityDescription: String? = nil
    ) -> NSImage? {
        let image = NSImage(
            systemSymbolName: name,
            accessibilityDescription: accessibilityDescription
        )
        image?.isTemplate = true
        return image
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateRuntimeState(forceEngineRefresh: true)
        rebuildStatusMenu(menu)
    }

    @objc private func toggleScrolling() {
        settings.isEnabled.toggle()
    }

    @objc private func selectFeel(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let feel = ScrollFeel(rawValue: rawValue) else { return }
        settings.feel = feel
    }

    @objc private func selectSpeed(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let speed = ScrollSpeed(rawValue: rawValue) else { return }
        settings.speed = speed
    }

    @objc private func openAccessibilitySettings() {
        settings.openPrivacySettings()
    }

    @objc private func quitMacMouseFixFromMenu() {
        settings.quitCompetingDriver()
    }

    @objc private func retryEngineFromMenu() {
        settings.retryEngine()
    }

    @objc private func openSettings() {
        showSettings()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func attachWindowDelegates() {
        for window in NSApp.windows where window.canBecomeKey {
            window.delegate = self
        }
    }

    private func hideToMenuBar() {
        guard !isTerminating else { return }

        if !settings.showInMenuBar {
            settings.showInMenuBar = true
        } else {
            configureStatusItem()
        }

        guard !isHiddenToMenuBar else { return }
        isHiddenToMenuBar = true
        for window in NSApp.windows where window.canBecomeKey {
            window.orderOut(nil)
        }
        NSApp.setActivationPolicy(.accessory)
    }

    private func showSettings() {
        isHiddenToMenuBar = false
        NSApp.setActivationPolicy(.regular)
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)

        attachWindowDelegates()
        if let window = NSApp.windows.first(where: { $0.canBecomeKey }) {
            window.delegate = self
            window.makeKeyAndOrderFront(nil)
        }
    }
}
