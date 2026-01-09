//
//  SettingsView.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-14.
//

import SwiftUI
import ServiceManagement
import AppKit

/// Settings view with tabbed interface
struct SettingsView: View {
    @Bindable var appModel: AppModel

    @State private var sessionKey: String = ""
    @State private var isSessionKeyShown: Bool = false
    @State private var isValidatingSessionKey: Bool = false
    @State private var sessionKeyValidationMessage: String?
    @State private var hasSessionKeyValidationSucceeded: Bool = false

    @State private var isSendingTestNotification: Bool = false
    @State private var testNotificationMessage: String?
    @State private var hasTestNotificationSucceeded: Bool = false
    @State private var notificationError: String?

    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
            notificationsTab
                .tabItem { Label("Notifications", systemImage: "bell") }
            aboutTab
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 500)
        .onAppear {
            loadSettings()
        }
        .onChange(of: appModel.settings.hasNotificationsEnabled) { _, newValue in
            if newValue {
                Task {
                    await appModel.requestNotificationPermissionIfNeeded()
                    await updateNotificationStatus()
                }
            } else {
                notificationError = nil
            }
        }
        .onChange(of: launchAtLogin) { _, newValue in
            updateLaunchAtLogin(newValue)
        }
    }

    // MARK: - General Tab

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !appModel.isReady {
                VStack {
                    Spacer()
                    ProgressView("Loading settings...")
                        .controlSize(.large)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                sessionKeySection
                refreshIntervalSection
                sonnetUsageSection
                iconStyleSection
                launchAtLoginSection
            }
        }
        .padding(24)
    }

    // MARK: - Session Key Section

    private var sessionKeySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session Key")
                .font(.subheadline)

            Text("Your Claude.ai session key authenticates API requests. Find this in your browser's cookies.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                if isSessionKeyShown {
                    TextField("sk-ant-...", text: $sessionKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                } else {
                    SecureField("sk-ant-...", text: $sessionKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                }

                Button(action: { isSessionKeyShown.toggle() }) {
                    Image(systemName: isSessionKeyShown ? "eye.slash" : "eye")
                }
                .buttonStyle(.borderless)
                .help(isSessionKeyShown ? "Hide session key" : "Show session key")

                if !sessionKey.isEmpty {
                    Button(action: clearSessionKey) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Clear session key")
                }
            }

            HStack {
                Button("Validate & Save") {
                    Task {
                        await validateAndSaveSessionKey()
                    }
                }
                .controlSize(.small)
                .disabled(sessionKey.isEmpty || isValidatingSessionKey)

                if isValidatingSessionKey {
                    ProgressView()
                        .controlSize(.small)
                }

                if let message = sessionKeyValidationMessage {
                    Label(message, systemImage: hasSessionKeyValidationSucceeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(hasSessionKeyValidationSucceeded ? .green : .red)
                }

                Spacer()
            }
        }
        .padding()
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Refresh Interval Section

    private var refreshIntervalSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Refresh Interval")
                    .font(.subheadline)
                Text("How often to check your usage data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("", selection: $appModel.settings.refreshInterval) {
                Text("1 minute").tag(60.0)
                Text("5 minutes").tag(300.0)
                Text("10 minutes").tag(600.0)
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 120)
        }
        .padding()
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Sonnet Usage Section

    private var sonnetUsageSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Show Sonnet Usage")
                    .font(.subheadline)
                Text("Display weekly Sonnet usage in the menu bar popover")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: $appModel.settings.isSonnetUsageShown)
                .labelsHidden()
        }
        .padding()
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Icon Style Section

    private var iconStyleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Menu Bar Icon Style")
                .font(.subheadline)

            Text("Choose how the usage indicator appears in your menu bar")
                .font(.caption)
                .foregroundStyle(.secondary)

            IconStylePicker(selection: $appModel.settings.iconStyle)
        }
        .padding()
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Launch at Login Section

    private var launchAtLoginSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Start at Login")
                    .font(.subheadline)
                Text("Automatically launch ClaudeMeter when you log in")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: $launchAtLogin)
                .labelsHidden()
        }
        .padding()
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Notifications Tab

    private var notificationsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            enableNotificationsSection
            thresholdsSection
                .opacity(appModel.settings.hasNotificationsEnabled ? 1 : 0.5)
                .allowsHitTesting(appModel.settings.hasNotificationsEnabled)
            resetNotificationSection
                .opacity(appModel.settings.hasNotificationsEnabled ? 1 : 0.5)
                .allowsHitTesting(appModel.settings.hasNotificationsEnabled)
            testNotificationSection
                .opacity(appModel.settings.hasNotificationsEnabled ? 1 : 0.5)
                .allowsHitTesting(appModel.settings.hasNotificationsEnabled)
        }
        .padding(24)
    }

    private var enableNotificationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enable Notifications")
                        .font(.subheadline)
                    Text("Get notified when session usage thresholds are reached")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: $appModel.settings.hasNotificationsEnabled)
                    .labelsHidden()
            }

            if let error = notificationError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Open Settings") {
                        openSystemNotificationSettings()
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }
            }
        }
        .padding()
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var thresholdsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Warning Threshold")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(warningThresholdValue))%")
                        .foregroundStyle(.orange)
                        .font(.subheadline.monospacedDigit())
                }

                Slider(
                    value: warningThresholdBinding,
                    in: Constants.Thresholds.Notification.warningMin...Constants.Thresholds.Notification.warningMax,
                    step: Constants.Thresholds.Notification.step
                )
                .tint(.orange)

                Text("Get notified when session usage reaches this percentage")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Critical Threshold")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(criticalThresholdValue))%")
                        .foregroundStyle(.red)
                        .font(.subheadline.monospacedDigit())
                }

                Slider(
                    value: criticalThresholdBinding,
                    in: Constants.Thresholds.Notification.criticalMin...Constants.Thresholds.Notification.criticalMax,
                    step: Constants.Thresholds.Notification.step
                )
                .tint(.red)

                Text("Get urgent notification when session usage reaches this percentage")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if criticalThresholdValue <= warningThresholdValue {
                    Label("Critical threshold must be higher than warning", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding()
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var resetNotificationSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Notify on Session Reset")
                    .font(.subheadline)
                Text("Get notified when your usage limit resets")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: isNotifiedOnResetBinding)
                .labelsHidden()
        }
        .padding()
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var testNotificationSection: some View {
        HStack {
            Button("Send Test Notification") {
                Task {
                    await sendTestNotification()
                }
            }
            .controlSize(.small)
            .disabled(isSendingTestNotification)

            if isSendingTestNotification {
                ProgressView()
                    .controlSize(.small)
            }

            if let message = testNotificationMessage {
                Label(message, systemImage: hasTestNotificationSucceeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(hasTestNotificationSucceeded ? .green : .red)
            }

            Spacer()
        }
        .padding()
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Bindings

    private var warningThresholdBinding: Binding<Double> {
        Binding(
            get: { appModel.settings.notificationThresholds.warningThreshold },
            set: { appModel.settings.notificationThresholds.warningThreshold = $0 }
        )
    }

    private var criticalThresholdBinding: Binding<Double> {
        Binding(
            get: { appModel.settings.notificationThresholds.criticalThreshold },
            set: { appModel.settings.notificationThresholds.criticalThreshold = $0 }
        )
    }

    private var isNotifiedOnResetBinding: Binding<Bool> {
        Binding(
            get: { appModel.settings.notificationThresholds.isNotifiedOnReset },
            set: { appModel.settings.notificationThresholds.isNotifiedOnReset = $0 }
        )
    }

    private var warningThresholdValue: Double {
        appModel.settings.notificationThresholds.warningThreshold
    }

    private var criticalThresholdValue: Double {
        appModel.settings.notificationThresholds.criticalThreshold
    }

    // MARK: - About Tab

    private var aboutTab: some View {
        VStack(spacing: 24) {
            // App Icon
            if let appIconImage = NSImage(named: "AppIcon") {
                Image(nsImage: appIconImage)
                    .resizable()
                    .frame(width: 128, height: 128)
                    .cornerRadius(22)
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            } else {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)
            }

            // App Name & Version
            VStack(spacing: 8) {
                Text("ClaudeMeter")
                    .font(.system(size: 28, weight: .semibold))

                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                   let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                    Text("Version \(version) (\(build))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Copyright
            VStack(spacing: 4) {
                Text("© 2025 Edd Mann")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Monitor your Claude.ai usage limits.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Project Link
            Link(destination: URL(string: "https://github.com/eddmann/ClaudeMeter")!) {
                HStack {
                    Image(systemName: "link.circle.fill")
                    Text("View Project on GitHub")
                }
                .frame(maxWidth: 280)
                .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func loadSettings() {
        Task { @MainActor in
            sessionKey = await appModel.loadSessionKey() ?? ""
            await updateNotificationStatus()
        }
    }

    @MainActor
    private func updateNotificationStatus() async {
        let hasPermission = await appModel.checkNotificationPermissions()
        if appModel.settings.hasNotificationsEnabled && !hasPermission {
            notificationError = "Notifications disabled in System Settings"
        } else {
            notificationError = nil
        }
    }

    @MainActor
    private func validateAndSaveSessionKey() async {
        guard !sessionKey.isEmpty else {
            sessionKeyValidationMessage = "Session key cannot be empty"
            hasSessionKeyValidationSucceeded = false
            return
        }

        isValidatingSessionKey = true
        sessionKeyValidationMessage = nil
        hasSessionKeyValidationSucceeded = false

        do {
            let isValid = try await appModel.validateAndSaveSessionKey(sessionKey)

            if isValid {
                sessionKeyValidationMessage = "Session key saved"
                hasSessionKeyValidationSucceeded = true

                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2))
                    sessionKeyValidationMessage = nil
                    hasSessionKeyValidationSucceeded = false
                }
            } else {
                sessionKeyValidationMessage = "Session key validation failed"
                hasSessionKeyValidationSucceeded = false
            }
        } catch let error as SessionKeyError {
            sessionKeyValidationMessage = error.localizedDescription
            hasSessionKeyValidationSucceeded = false
        } catch {
            sessionKeyValidationMessage = "Validation failed: \(error.localizedDescription)"
            hasSessionKeyValidationSucceeded = false
        }

        isValidatingSessionKey = false
    }

    private func clearSessionKey() {
        Task { @MainActor in
            do {
                try await appModel.clearSessionKey()
                sessionKey = ""
                sessionKeyValidationMessage = nil
                hasSessionKeyValidationSucceeded = false
            } catch {
                sessionKeyValidationMessage = "Failed to clear: \(error.localizedDescription)"
                hasSessionKeyValidationSucceeded = false
            }
        }
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Revert the toggle if it failed
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    @MainActor
    private func sendTestNotification() async {
        isSendingTestNotification = true
        testNotificationMessage = nil
        hasTestNotificationSucceeded = false

        do {
            let hasPermission = await appModel.checkNotificationPermissions()
            if !hasPermission {
                await appModel.requestNotificationPermissionIfNeeded()
                let granted = await appModel.checkNotificationPermissions()
                if !granted {
                    testNotificationMessage = "Permission denied"
                    hasTestNotificationSucceeded = false
                    isSendingTestNotification = false
                    return
                }
            }

            // Send test notification
            try await appModel.sendTestNotification()

            testNotificationMessage = "Test notification sent!"
            hasTestNotificationSucceeded = true

            // Clear message after 2 seconds
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                testNotificationMessage = nil
                hasTestNotificationSucceeded = false
            }
        } catch {
            testNotificationMessage = "Failed: \(error.localizedDescription)"
            hasTestNotificationSucceeded = false
        }

        isSendingTestNotification = false
    }

    private func openSystemNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }
}
