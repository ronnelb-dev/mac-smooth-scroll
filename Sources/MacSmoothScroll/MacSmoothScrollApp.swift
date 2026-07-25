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
                .frame(minWidth: 640, idealWidth: 680, minHeight: 600, idealHeight: 650)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 680, height: 650)
        .defaultPosition(.center)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let settings = ScrollSettings()
    private lazy var scrollEngine = SmoothScrollEngine(settings: settings)
    private var statusItem: NSStatusItem?
    private var permissionTimer: Timer?
    private var isHiddenToMenuBar = false
    private var isTerminating = false
    private let launchedInBackground = ProcessInfo.processInfo.arguments.contains("--background")

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(launchedInBackground ? .accessory : .regular)
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

        configureStatusItem()
        updateRuntimeState()
        scrollEngine.refresh()
        settings.migrateLaunchAtLoginRegistration()

        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.updateRuntimeState()
        }
        RunLoop.main.add(permissionTimer!, forMode: .common)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.attachWindowDelegates()
            if self.launchedInBackground {
                self.hideToMenuBar()
            } else {
                self.showSettings()
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
        configureStatusItem()
        scrollEngine.refresh()
    }

    private func updateRuntimeState() {
        let wasGranted = settings.permissionGranted
        let wasCompetitorRunning = settings.competingDriverRunning
        // A modifying CGEvent tap is authorized through Accessibility. The
        // Input Monitoring preflight API is for listen-only monitoring and
        // should not block this app after Accessibility has been granted.
        settings.permissionGranted = AXIsProcessTrusted()
        settings.competingDriverRunning =
            !NSRunningApplication.runningApplications(withBundleIdentifier: "com.nuebling.mac-mouse-fix").isEmpty ||
            !NSRunningApplication.runningApplications(withBundleIdentifier: "com.nuebling.mac-mouse-fix.helper").isEmpty

        if settings.permissionGranted != wasGranted ||
            settings.competingDriverRunning != wasCompetitorRunning {
            scrollEngine.refresh()
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

        statusItem?.button?.image = NSImage(
            systemSymbolName: settings.isEnabled ? "computermouse.fill" : "computermouse",
            accessibilityDescription: "Mac Smooth Scroll"
        )
        statusItem?.button?.image?.isTemplate = true

        let menu = NSMenu()
        let toggle = NSMenuItem(
            title: settings.isEnabled ? "Turn Smooth Scrolling Off" : "Turn Smooth Scrolling On",
            action: #selector(toggleScrolling),
            keyEquivalent: ""
        )
        toggle.target = self
        menu.addItem(toggle)
        menu.addItem(.separator())

        let open = NSMenuItem(title: "Open Mac Smooth Scroll…", action: #selector(openSettings), keyEquivalent: ",")
        open.target = self
        menu.addItem(open)

        let quit = NSMenuItem(title: "Quit Mac Smooth Scroll", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem?.menu = menu
    }

    @objc private func toggleScrolling() {
        settings.isEnabled.toggle()
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
