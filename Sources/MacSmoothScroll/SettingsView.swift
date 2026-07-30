import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: ScrollSettings
    @State private var showingResetConfirmation = false
    @State private var diagnosticsCopied = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            settingsTabBar
            Divider()
            selectedSettingsPage
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $settings.isSetupPresented) {
            FirstRunSetupView()
                .environmentObject(settings)
        }
        .alert("Reset scrolling settings?", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                settings.resetDefaults()
            }
        } message: {
            Text("Scrolling, advanced tuning, and modifier keys will return to their defaults.")
        }
    }

    @ViewBuilder
    private var selectedSettingsPage: some View {
        switch settings.selectedTab {
        case .scrolling:
            settingsPage {
                scrollingSection
                advancedScrollingSection
            }
        case .modifierKeys:
            settingsPage {
                modifierSection
            }
        case .app:
            settingsPage {
                appSection
                systemHealthSection
            }
        }
    }

    private func settingsPage<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        Form {
            content()
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private var settingsTabBar: some View {
        HStack(spacing: 8) {
            ForEach(SettingsTab.allCases) { tab in
                Button {
                    settings.selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.symbolName)
                            .font(.system(size: 17, weight: .medium))
                        Text(tab.title)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                    }
                    .foregroundStyle(
                        settings.selectedTab == tab ? Color.accentColor : Color.primary
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                    .background(
                        settings.selectedTab == tab
                            ? Color.accentColor.opacity(0.14)
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(
                    settings.selectedTab == tab ? .isSelected : []
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(.bar)
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

    private var systemHealthSection: some View {
        Section {
            accessibilityHealthRow
            engineHealthRow
            competingDriverHealthRow
            launchAtLoginHealthRow

            HStack {
                Button {
                    copyDiagnostics()
                } label: {
                    Label("Copy Diagnostics", systemImage: "doc.on.doc")
                }
                .accessibilityHint("Copies privacy-safe app and system health information")

                Spacer()

                if diagnosticsCopied {
                    Label("Copied", systemImage: "checkmark")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .accessibilityAddTraits(.isStaticText)
                }
            }
        } header: {
            Text("System Health")
        } footer: {
            Text("Diagnostics contain app and system status only. Mouse activity and personal information are never included.")
        }
    }

    private var accessibilityHealthRow: some View {
        healthRow(
            title: "Accessibility",
            detail: settings.permissionGranted
                ? "Mac Smooth Scroll can transform wheel events."
                : "Permission is required to transform wheel events.",
            status: settings.systemHealth.accessibility.rawValue,
            symbol: settings.permissionGranted ? "checkmark.shield.fill" : "hand.raised.fill",
            tone: settings.permissionGranted ? .ready : .warning
        ) {
            if !settings.permissionGranted {
                Button("Request Permission") {
                    settings.requestPermissions()
                }
                .buttonStyle(.borderedProminent)
                Button("Open Settings") {
                    settings.openPrivacySettings()
                }
                .help("Open Accessibility Settings")
            }
        }
    }

    private var engineHealthRow: some View {
        healthRow(
            title: "Scroll engine",
            detail: engineHealthDetail,
            status: settings.systemHealth.engine.rawValue,
            symbol: engineHealthSymbol,
            tone: engineHealthTone
        ) {
            switch settings.engineStatus {
            case .disabled:
                Button("Turn On") {
                    settings.isEnabled = true
                }
                .buttonStyle(.borderedProminent)
            case .startFailed:
                Button("Retry") {
                    settings.retryEngine()
                }
                .buttonStyle(.borderedProminent)
            default:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private var competingDriverHealthRow: some View {
        healthRow(
            title: "Mouse drivers",
            detail: settings.competingDriverRunning
                ? "Another wheel driver can duplicate or distort scrolling."
                : "No known conflicting mouse driver is running.",
            status: settings.systemHealth.competingDriver.rawValue,
            symbol: settings.competingDriverRunning
                ? "exclamationmark.triangle.fill"
                : "checkmark.circle.fill",
            tone: settings.competingDriverRunning ? .warning : .ready
        ) {
            if settings.competingDriverRunning {
                Button("Quit Mac Mouse Fix") {
                    settings.quitCompetingDriver()
                }
                .buttonStyle(.borderedProminent)
            }
        }

        if let message = settings.competingDriverRecoveryMessage {
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
                .accessibilityLabel("Mouse driver recovery failed. \(message)")
        }
    }

    private var launchAtLoginHealthRow: some View {
        healthRow(
            title: "Launch at login",
            detail: settings.launchAtLoginDetail,
            status: settings.systemHealth.launchAtLogin.rawValue,
            symbol: launchAtLoginSymbol,
            tone: launchAtLoginTone
        ) {
            switch settings.launchAtLoginHealthStatus.recovery {
            case .openSettings:
                Button("Open Settings") {
                    settings.openLoginItemsSettings()
                }
                .help("Open Login Items Settings")
            case .repair:
                Button("Repair") {
                    settings.repairLaunchAtLogin()
                }
                .buttonStyle(.borderedProminent)
            case .openApplications:
                Button("Open Applications") {
                    settings.openApplicationsFolder()
                }
            case .none:
                EmptyView()
            }
        }
    }

    private var scrollingSection: some View {
        Section {
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
                    Text("Feel")
                    Text("Choose the balance between responsiveness and glide.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            LabeledContent {
                Picker("Speed", selection: $settings.speed) {
                    ForEach(ScrollSpeed.allCases) { speed in
                        Text(speed.rawValue).tag(speed)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 250)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Speed")
                    Text("Control how far normal wheel movement scrolls.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Toggle(isOn: $settings.reverseDirection) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reverse scrolling")
                    Text("Reverse external-mouse scrolling without changing trackpad behavior.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var advancedScrollingSection: some View {
        Section {
            LabeledContent {
                Picker("Smoothness", selection: $settings.smoothness) {
                    ForEach(Smoothness.allCases) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 250)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Smoothness")
                    Text("Control how gradually scrolling slows after each wheel movement.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            minimumWheelStepRow

            Toggle(isOn: $settings.adaptivePrecision) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Adaptive precision")
                    Text("Make slow wheel movements smaller and more precise.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Toggle(isOn: $settings.accelerationEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scroll acceleration")
                    Text("Increase movement when the wheel is turned rapidly.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Toggle(isOn: $settings.trackpadSimulation) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Trackpad-like gestures")
                    Text("Add gesture phases for natural scrolling and horizontal navigation.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Advanced Scrolling")
        } footer: {
            Text("These controls fine-tune discrete mouse-wheel input. Trackpads and Magic Mouse remain unchanged.")
        }
    }

    private var minimumWheelStepRow: some View {
        VStack(alignment: .leading, spacing: 7) {
            Toggle(isOn: $settings.minimumStepEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Minimum wheel step")
                    Text("Minimum final distance after speed and adaptive precision.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityHint(
                "When disabled, small wheel movements are not raised to the saved minimum."
            )

            HStack(spacing: 7) {
                StepSlider(
                    value: $settings.minimumStepDistance,
                    range: ScrollStep.range,
                    step: ScrollStep.increment
                )
                .frame(minWidth: 155, maxWidth: .infinity)

                TextField(
                    "Minimum wheel step",
                    value: $settings.minimumStepDistance,
                    format: .number.precision(.fractionLength(2))
                )
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .frame(width: 60)
                .accessibilityLabel("Minimum wheel step value")
                .accessibilityValue(
                    "\(ScrollStep.formatted(settings.minimumStepDistance)) points"
                )

                Text("pt")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                Stepper(
                    "Minimum wheel step",
                    value: $settings.minimumStepDistance,
                    in: ScrollStep.range,
                    step: ScrollStep.increment
                )
                .labelsHidden()
                .fixedSize()
            }
            .disabled(!settings.minimumStepEnabled)

            HStack(spacing: 8) {
                Text(
                    settings.minimumStepEnabled
                        ? "Modifier keys can intentionally reduce or increase this distance."
                        : "The saved value will be used again when this feature is enabled."
                )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(
                    "Range \(ScrollStep.formatted(ScrollStep.minimum))–\(ScrollStep.formatted(ScrollStep.maximum)) pt"
                )
                .font(.caption)
                .foregroundStyle(.tertiary)

                Text("Default \(ScrollStep.formatted(ScrollStep.defaultValue)) pt")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Button("Reset") {
                    settings.resetMinimumStepDistance()
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .disabled(
                    settings.minimumStepEnabled &&
                        settings.minimumStepDistance == ScrollStep.defaultValue
                )
                .accessibilityLabel(
                    "Enable minimum wheel step and reset it to 18 points"
                )
            }
        }
        .padding(.vertical, 2)
    }

    private var modifierSection: some View {
        Section {
            modifierRow(
                title: "Horizontal scrolling",
                detail: "Convert vertical-dominant movement; combines with Faster or Precision.",
                selection: $settings.horizontalModifier
            )
            modifierRow(
                title: "Zoom",
                detail: "Pass the modifier only when no transform action is active.",
                selection: $settings.zoomModifier
            )
            modifierRow(
                title: "Faster scrolling",
                detail: "Temporarily increase speed unless Precision is active.",
                selection: $settings.swiftModifier
            )
            modifierRow(
                title: "Precision scrolling",
                detail: "Temporarily reduce speed and take priority over Faster.",
                selection: $settings.preciseModifier
            )
        } footer: {
            Text("Assignments are frozen for each wheel burst. Horizontal can combine with Faster or Precision; transform actions suppress Zoom.")
        }
    }

    private var appSection: some View {
        Section {
            Toggle("Show in menu bar", isOn: $settings.showInMenuBar)
            Toggle("Launch at login", isOn: $settings.launchAtLogin)

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

            LabeledContent {
                Button("Run Setup Again…") {
                    settings.presentSetup()
                }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Setup assistant")
                    Text("Review installation, Accessibility, scrolling, and launch-at-login setup.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Button("Reset Scrolling Settings…") {
                    showingResetConfirmation = true
                }
                Spacer()
                Text("Version \(appVersion) • Apple Silicon")
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
        if settings.engineStatus == .startFailed { return .red }
        return settings.engineStatus == .active ? .green : .orange
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "Unknown"
    }

    private var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            ?? "Unknown"
    }

    private var engineHealthDetail: String {
        switch settings.engineStatus {
        case .waiting:
            "The engine is checking whether it can start."
        case .active:
            "Discrete external-mouse wheel events are being transformed."
        case .recovering:
            "The event tap was interrupted and is being restored automatically."
        case .disabled:
            "Smooth scrolling is intentionally turned off."
        case .permissionBlocked:
            "The engine will start after Accessibility permission is granted."
        case .driverConflict:
            "The engine is paused until Mac Mouse Fix quits."
        case .startFailed:
            "The event tap could not be created. Check permission, then retry."
        }
    }

    private var engineHealthSymbol: String {
        switch settings.engineStatus {
        case .waiting: "clock.fill"
        case .active: "checkmark.circle.fill"
        case .recovering: "arrow.clockwise.circle.fill"
        case .disabled: "pause.circle.fill"
        case .permissionBlocked: "lock.fill"
        case .driverConflict: "exclamationmark.triangle.fill"
        case .startFailed: "xmark.octagon.fill"
        }
    }

    private var engineHealthTone: HealthTone {
        switch settings.engineStatus {
        case .active: .ready
        case .waiting, .recovering, .disabled: .neutral
        case .permissionBlocked, .driverConflict: .warning
        case .startFailed: .error
        }
    }

    private var launchAtLoginSymbol: String {
        switch settings.launchAtLoginHealthStatus {
        case .enabled: "checkmark.circle.fill"
        case .disabled: "minus.circle.fill"
        case .approvalRequired: "person.badge.clock.fill"
        case .registrationMissing: "arrow.clockwise.circle.fill"
        case .helperMissing: "questionmark.folder.fill"
        case .unavailable: "exclamationmark.circle.fill"
        }
    }

    private var launchAtLoginTone: HealthTone {
        switch settings.launchAtLoginHealthStatus {
        case .enabled: .ready
        case .disabled: .neutral
        case .approvalRequired, .registrationMissing: .warning
        case .helperMissing, .unavailable: .error
        }
    }

    private func healthRow<Actions: View>(
        title: String,
        detail: String,
        status: String,
        symbol: String,
        tone: HealthTone,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tone.color)
                .frame(width: 22, height: 22)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 6) {
                Text(status)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tone.color)
                HStack(spacing: 6) {
                    actions()
                }
                .controlSize(.small)
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title): \(status). \(detail)")
    }

    private func copyDiagnostics() {
        let health = settings.systemHealth
        let diagnostics = SystemDiagnostics(
            appVersion: appVersion,
            appBuild: appBuild,
            macOSVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            architecture: SystemDiagnostics.currentArchitecture,
            smoothScrollingEnabled: settings.isEnabled,
            accessibility: health.accessibility,
            engine: health.engine,
            competingDriver: health.competingDriver,
            showInMenuBar: settings.showInMenuBar,
            launchAtLoginEnabled: settings.launchAtLogin,
            launchAtLogin: health.launchAtLogin
        )

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(diagnostics.report, forType: .string)
        diagnosticsCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            diagnosticsCopied = false
        }
    }
}

private enum HealthTone {
    case ready
    case neutral
    case warning
    case error

    var color: Color {
        switch self {
        case .ready: .green
        case .neutral: .secondary
        case .warning: .orange
        case .error: .red
        }
    }
}

private struct StepSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    @FocusState private var isFocused: Bool
    private let thumbDiameter: CGFloat = 18

    var body: some View {
        GeometryReader { geometry in
            let trackWidth = max(geometry.size.width - thumbDiameter, 1)
            let progress = CGFloat(
                (value - range.lowerBound) /
                    (range.upperBound - range.lowerBound)
            )
            let thumbX = (thumbDiameter / 2) + (trackWidth * progress)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.35))
                    .frame(width: trackWidth, height: 4)
                    .offset(x: thumbDiameter / 2)

                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: max(trackWidth * progress, 2), height: 4)
                    .offset(x: thumbDiameter / 2)

                Circle()
                    .fill(.white)
                    .frame(width: thumbDiameter, height: thumbDiameter)
                    .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
                    .position(x: thumbX, y: geometry.size.height / 2)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let rawProgress =
                            (gesture.location.x - (thumbDiameter / 2)) /
                            trackWidth
                        let clampedProgress = min(max(rawProgress, 0), 1)
                        value = range.lowerBound +
                            (Double(clampedProgress) * (range.upperBound - range.lowerBound))
                    }
            )
        }
        .frame(height: 20)
        .focusable()
        .focused($isFocused)
        .overlay {
            if isFocused {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.accentColor, lineWidth: 2)
                    .padding(-3)
            }
        }
        .onMoveCommand { direction in
            switch direction {
            case .left, .down:
                adjust(bySteps: -1)
            case .right, .up:
                adjust(bySteps: 1)
            default:
                break
            }
        }
        .accessibilityRepresentation {
            Slider(value: $value, in: range, step: step) {
                Text("Minimum wheel step")
            }
            .focused($isFocused)
            .accessibilityValue("\(ScrollStep.formatted(value)) points")
            .accessibilityHint(
                "Use arrow keys or the VoiceOver adjust gesture to change by 0.01 points"
            )
        }
    }

    private func adjust(bySteps steps: Int) {
        let adjusted = ScrollStep.adjusted(value, bySteps: steps)
        value = min(max(adjusted, range.lowerBound), range.upperBound)
    }
}
