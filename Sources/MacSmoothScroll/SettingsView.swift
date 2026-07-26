import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: ScrollSettings
    @State private var showingResetConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            Form {
                competingDriverSection
                permissionSection
                scrollingSection
                modifierSection
                appSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("Reset scrolling settings?", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                settings.resetDefaults()
            }
        } message: {
            Text("Smoothness, speed, direction, precision, and modifier keys will return to their defaults.")
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Group {
                if let brandIcon = NSImage(named: "BrandIcon") {
                    Image(nsImage: brandIcon)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: "computermouse.fill")
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.teal, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
            }
            .frame(width: 48, height: 48)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("Mac Smooth Scroll")
                    .font(.system(size: 20, weight: .semibold))
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 7, height: 7)
                    Text(settings.engineMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Toggle("Smooth scrolling", isOn: $settings.isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .accessibilityLabel("Smooth scrolling")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    @ViewBuilder
    private var competingDriverSection: some View {
        if settings.competingDriverRunning {
            Section {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundStyle(.yellow)
                        .frame(width: 26)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mac Mouse Fix is currently running")
                            .font(.headline)
                        Text("Quit Mac Mouse Fix before using Mac Smooth Scroll. Running two mouse drivers together can duplicate or distort wheel input.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 5)
            }
        }
    }

    @ViewBuilder
    private var permissionSection: some View {
        if !settings.permissionGranted {
            Section {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "hand.raised.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                        .frame(width: 26)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Allow mouse access")
                            .font(.headline)
                        Text("macOS requires Accessibility permission before Mac Smooth Scroll can transform wheel events.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack {
                            Button("Request Permission") {
                                settings.requestPermissions()
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Open System Settings") {
                                settings.openPrivacySettings()
                            }
                        }
                        .padding(.top, 2)

                        Text("Already enabled? In System Settings, switch Mac Smooth Scroll off and on again. If that does not work, remove the old entry and add this app again.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)
                    }
                }
                .padding(.vertical, 5)
            }
        }
    }

    private var scrollingSection: some View {
        Section("Scrolling") {
            LabeledContent("Smoothness") {
                Picker("Smoothness", selection: $settings.smoothness) {
                    ForEach(Smoothness.allCases) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 250)
            }

            LabeledContent("Speed") {
                Picker("Speed", selection: $settings.speed) {
                    ForEach(ScrollSpeed.allCases) { speed in
                        Text(speed.rawValue).tag(speed)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 250)
            }

            LabeledContent {
                Picker("Scroll feel", selection: $settings.feel) {
                    ForEach(ScrollFeel.allCases) { feel in
                        Text(feel.rawValue).tag(feel)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 250)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scroll feel")
                    Text("Controls responsiveness, acceleration, and direction changes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Toggle(isOn: $settings.trackpadSimulation) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Trackpad simulation")
                    Text("Adds gesture phases for natural scrolling and horizontal navigation.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Toggle(isOn: $settings.reverseDirection) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reverse direction")
                    Text("Reverse external mouse scrolling without changing trackpad behavior.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Toggle(isOn: $settings.adaptivePrecision) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Adaptive precision")
                    Text("Slow wheel movements automatically produce smaller, more precise steps.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var modifierSection: some View {
        Section {
            modifierRow(
                title: "Scroll horizontally",
                detail: "Convert vertical wheel movement to horizontal scrolling.",
                selection: $settings.horizontalModifier
            )
            modifierRow(
                title: "Zoom in or out",
                detail: "Pass the modifier through to apps with scroll-to-zoom support.",
                selection: $settings.zoomModifier
            )
            modifierRow(
                title: "Scroll swiftly",
                detail: "Temporarily increase scrolling speed.",
                selection: $settings.swiftModifier
            )
            modifierRow(
                title: "Scroll precisely",
                detail: "Temporarily reduce scrolling speed.",
                selection: $settings.preciseModifier
            )
        } header: {
            Text("Keyboard Modifiers")
        } footer: {
            Text("Transform actions take priority over zoom. Precision takes priority over swift scrolling.")
        }
    }

    private var appSection: some View {
        Section("App") {
            Toggle("Show in menu bar", isOn: $settings.showInMenuBar)
            Toggle("Launch at login", isOn: $settings.launchAtLogin)

            if let message = settings.launchAtLoginMessage {
                VStack(alignment: .leading, spacing: 6) {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                    Button("Open Login Items Settings") {
                        settings.openLoginItemsSettings()
                    }
                    .font(.caption)
                }
            }

            LabeledContent {
                Button {
                    settings.hideToMenuBar()
                } label: {
                    Label("Hide to Menu Bar", systemImage: "menubar.rectangle")
                }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Run in background")
                    Text("Hide the window and Dock icon while smooth scrolling stays active.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Button("Reset Scrolling Settings…") {
                    showingResetConfirmation = true
                }
                Spacer()
                Text("Version 0.2.0 • Apple Silicon")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func modifierRow(
        title: String,
        detail: String,
        selection: Binding<ModifierKey>
    ) -> some View {
        LabeledContent {
            Picker(title, selection: selection) {
                ForEach(ModifierKey.allCases) { key in
                    Text("\(key.symbol)  \(key.title)").tag(key)
                }
            }
            .labelsHidden()
            .frame(width: 155)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusColor: Color {
        if !settings.isEnabled { return .secondary }
        return settings.permissionGranted ? .green : .orange
    }
}
