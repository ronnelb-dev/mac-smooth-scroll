import AppKit
import SwiftUI

struct FirstRunSetupView: View {
    @EnvironmentObject private var settings: ScrollSettings
    @State private var step = SetupStep.applications

    var body: some View {
        VStack(spacing: 0) {
            setupHeader
            Divider()
            stepContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(32)
            Divider()
            controls
                .padding(20)
        }
        .frame(width: 560, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Mac Smooth Scroll setup")
    }

    private var setupHeader: some View {
        HStack(spacing: 14) {
            Group {
                if let brandIcon = NSImage(named: "BrandIcon") {
                    Image(nsImage: brandIcon)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: "computermouse.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.blue, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .frame(width: 46, height: 46)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("Set Up Mac Smooth Scroll")
                    .font(.title2.weight(.semibold))
                Text("Step \(step.rawValue + 1) of \(SetupStep.allCases.count)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            ProgressView(
                value: Double(step.rawValue + 1),
                total: Double(SetupStep.allCases.count)
            )
            .frame(width: 150)
            .accessibilityLabel("Setup progress")
            .accessibilityValue("Step \(step.rawValue + 1) of \(SetupStep.allCases.count)")
        }
        .padding(24)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .applications:
            applicationsStep
        case .accessibility:
            accessibilityStep
        case .scrollTest:
            scrollTestStep
        case .launchAtLogin:
            launchAtLoginStep
        }
    }

    private var applicationsStep: some View {
        setupCard(
            symbol: settings.isInstalledInApplications ? "checkmark.circle.fill" : "folder.badge.questionmark",
            symbolColor: settings.isInstalledInApplications ? .green : .orange,
            title: "Keep the app in Applications",
            detail: settings.isInstalledInApplications
                ? "Mac Smooth Scroll is installed in Applications and is ready for reliable permissions and launch-at-login support."
                : "Drag Mac Smooth Scroll into Applications before continuing. Running it from the DMG or Downloads can make permissions and launch at login unreliable."
        ) {
            statusLine(
                ready: settings.isInstalledInApplications,
                readyText: "Installed in Applications",
                attentionText: "Not running from Applications"
            )

            Button {
                settings.openApplicationsFolder()
            } label: {
                Label("Open Applications", systemImage: "folder")
            }
        }
    }

    private var accessibilityStep: some View {
        setupCard(
            symbol: settings.permissionGranted ? "checkmark.shield.fill" : "hand.raised.fill",
            symbolColor: settings.permissionGranted ? .green : .orange,
            title: "Allow Accessibility access",
            detail: "macOS requires Accessibility permission so Mac Smooth Scroll can replace discrete external mouse-wheel events with smooth scrolling."
        ) {
            statusLine(
                ready: settings.permissionGranted,
                readyText: "Accessibility is ready",
                attentionText: "Accessibility permission is required"
            )

            HStack {
                Button("Request Permission") {
                    settings.requestPermissions()
                }
                .disabled(settings.permissionGranted)

                Button("Open Accessibility Settings") {
                    settings.openPrivacySettings()
                }
            }
        }
    }

    private var scrollTestStep: some View {
        setupCard(
            symbol: settings.engineStatus == .active ? "computermouse.fill" : "computermouse",
            symbolColor: settings.engineStatus == .active ? .green : .orange,
            title: "Test your external mouse",
            detail: "Place the pointer over the area below and turn the mouse wheel. The rows should move with smooth, continuous motion."
        ) {
            statusLine(
                ready: settings.engineStatus == .active,
                readyText: "Scroll engine is active",
                attentionText: settings.engineMessage
            )

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(1...12, id: \.self) { index in
                        HStack {
                            Image(systemName: "arrow.up.and.down")
                                .foregroundStyle(.secondary)
                            Text("Smooth scrolling test \(index)")
                            Spacer()
                        }
                        .padding(10)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(10)
            }
            .frame(height: 145)
            .background(.background, in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.separator, lineWidth: 1)
            }
            .accessibilityLabel("Scrolling test area")

            if settings.engineStatus != .active {
                Button("Retry Scroll Engine") {
                    settings.retryEngine()
                }
            }
        }
    }

    private var launchAtLoginStep: some View {
        setupCard(
            symbol: "power",
            symbolColor: .blue,
            title: "Start automatically",
            detail: "Launch at login is optional. When enabled, Mac Smooth Scroll starts hidden in the menu bar and keeps your scrolling ready."
        ) {
            Toggle("Launch Mac Smooth Scroll at login", isOn: $settings.launchAtLogin)
                .toggleStyle(.switch)

            Text(settings.launchAtLogin
                 ? "You may need to approve Mac Smooth Scroll in System Settings → General → Login Items."
                 : "You can enable this later from the App section in Settings.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Label(
                "Your scrolling choices remain unchanged by this setup.",
                systemImage: "checkmark.circle"
            )
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }

    private func setupCard<Actions: View>(
        symbol: String,
        symbolColor: Color,
        title: String,
        detail: String,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        VStack(spacing: 22) {
            Image(systemName: symbol)
                .font(.system(size: 48, weight: .medium))
                .foregroundStyle(symbolColor)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(title)
                    .font(.title2.weight(.semibold))
                Text(detail)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 14) {
                actions()
            }
        }
        .frame(maxWidth: 460)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func statusLine(
        ready: Bool,
        readyText: String,
        attentionText: String
    ) -> some View {
        Label(
            ready ? readyText : attentionText,
            systemImage: ready ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
        )
        .font(.callout.weight(.medium))
        .foregroundStyle(ready ? Color.green : Color.orange)
        .accessibilityLabel(ready ? "Ready: \(readyText)" : "Attention: \(attentionText)")
    }

    private var controls: some View {
        HStack {
            Button("Finish Later") {
                settings.dismissSetup()
            }

            Spacer()

            Button("Back") {
                move(to: step.rawValue - 1)
            }
            .disabled(step == .applications)

            if step == .launchAtLogin {
                Button("Finish") {
                    settings.completeSetup()
                }
                .keyboardShortcut(.defaultAction)
            } else {
                Button("Continue") {
                    move(to: step.rawValue + 1)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func move(to rawValue: Int) {
        guard let nextStep = SetupStep(rawValue: rawValue) else { return }
        step = nextStep
    }
}
