import AppKit
import ServiceManagement
import SwiftUI

@main
struct MacSmoothScrollApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
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

final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = ScrollSettings()
    private lazy var scrollEngine = SmoothScrollEngine(settings: settings)
    private var statusItem: NSStatusItem?
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        settings.onChange = { [weak self] in
            self?.settingsDidChange()
        }
        settings.onOpenSettings = {
            AppDelegate.showSettingsWindow()
        }

        configureStatusItem()
        updateRuntimeState()
        scrollEngine.refresh()

        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.updateRuntimeState()
        }
        RunLoop.main.add(permissionTimer!, forMode: .common)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionTimer?.invalidate()
        scrollEngine.stop()
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
        Self.showSettingsWindow()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    static func showSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.canBecomeKey }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
