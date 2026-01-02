//
//  SettingsView.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-14.
//

import SwiftUI
import ServiceManagement

/// Settings view with tabbed interface
struct SettingsView: View {
    let container: DIContainer

    @State private var sessionKey: String = ""
    @State private var isSessionKeyShown: Bool = false
    @State private var isValidatingSessionKey: Bool = false
    @State private var sessionKeyValidationMessage: String?
    @State private var hasSessionKeyValidationSucceeded: Bool = false

    @State private var refreshInterval: Double = 60
    @State private var isSonnetUsageShown: Bool = false
    @State private var iconStyle: IconStyle = .battery

    @State private var hasNotificationsEnabled: Bool = true
    @State private var warningThreshold: Double = Constants.Thresholds.Notification.warningDefault
    @State private var criticalThreshold: Double = Constants.Thresholds.Notification.criticalDefault
    @State private var isNotifiedOnReset: Bool = true
    @State private var isSendingTestNotification: Bool = false
    @State private var testNotificationMessage: String?
    @State private var hasTestNotificationSucceeded: Bool = false
    @State private var notificationError: String?

    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled

    @State private var isLoading: Bool = true

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
        .modifier(SettingsAutoSaveModifier(
            refreshInterval: $refreshInterval,
            isSonnetUsageShown: $isSonnetUsageShown,
            iconStyle: $iconStyle,
            hasNotificationsEnabled: $hasNotificationsEnabled,
            warningThreshold: $warningThreshold,
            criticalThreshold: $criticalThreshold,
            isNotifiedOnReset: $isNotifiedOnReset,
            container: container
        ))
        .onChange(of: launchAtLogin) { _, newValue in
            updateLaunchAtLogin(newValue)
        }
    }

    // MARK: - General Tab

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isLoading {
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

            Picker("", selection: $refreshInterval) {
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

            Toggle("", isOn: $isSonnetUsageShown)
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

            IconStylePicker(selection: $iconStyle) { style in
                // Live preview
                NotificationCenter.default.post(name: .iconStylePreviewChanged, object: style)
            }
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
                .opacity(hasNotificationsEnabled ? 1 : 0.5)
                .allowsHitTesting(hasNotificationsEnabled)
            resetNotificationSection
                .opacity(hasNotificationsEnabled ? 1 : 0.5)
                .allowsHitTesting(hasNotificationsEnabled)
            testNotificationSection
                .opacity(hasNotificationsEnabled ? 1 : 0.5)
                .allowsHitTesting(hasNotificationsEnabled)
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

                Toggle("", isOn: $hasNotificationsEnabled)
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
                    Text("\(Int(warningThreshold))%")
                        .foregroundStyle(.orange)
                        .font(.subheadline.monospacedDigit())
                }

                Slider(
                    value: $warningThreshold,
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
                    Text("\(Int(criticalThreshold))%")
                        .foregroundStyle(.red)
                        .font(.subheadline.monospacedDigit())
                }

                Slider(
                    value: $criticalThreshold,
                    in: Constants.Thresholds.Notification.criticalMin...Constants.Thresholds.Notification.criticalMax,
                    step: Constants.Thresholds.Notification.step
                )
                .tint(.red)

                Text("Get urgent notification when session usage reaches this percentage")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if criticalThreshold <= warningThreshold {
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

            Toggle("", isOn: $isNotifiedOnReset)
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
        Task {
            // Load session key from keychain
            if let key = try? await container.keychainRepository.retrieve(account: "default") {
                sessionKey = key
            }

            // Load app settings
            let settings = await container.settingsRepository.load()
            refreshInterval = settings.refreshInterval
            isSonnetUsageShown = settings.isSonnetUsageShown
            iconStyle = settings.iconStyle
            warningThreshold = settings.notificationThresholds.warningThreshold
            criticalThreshold = settings.notificationThresholds.criticalThreshold
            isNotifiedOnReset = settings.notificationThresholds.isNotifiedOnReset

            // Check notification permissions
            let hasPermission = await container.notificationService.checkNotificationPermissions()
            hasNotificationsEnabled = settings.hasNotificationsEnabled && hasPermission

            if settings.hasNotificationsEnabled && !hasPermission {
                notificationError = "Notifications disabled in System Settings"
            }

            isLoading = false
        }
    }

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
            // Validate format
            let key = try SessionKey(sessionKey)

            // Validate with Claude API
            let isValid = try await container.usageService.validateSessionKey(key)

            if isValid {
                // Save to keychain
                try await container.keychainRepository.save(sessionKey: key.value, account: "default")

                sessionKeyValidationMessage = "Session key saved"
                hasSessionKeyValidationSucceeded = true

                // Clear success message after 2 seconds
                Task {
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
        Task {
            do {
                try await container.keychainRepository.delete(account: "default")
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

    private func sendTestNotification() async {
        isSendingTestNotification = true
        testNotificationMessage = nil
        hasTestNotificationSucceeded = false

        do {
            // Check if we have permission first
            let hasPermission = await container.notificationService.checkNotificationPermissions()
            if !hasPermission {
                let granted = try await container.notificationService.requestAuthorization()
                if !granted {
                    testNotificationMessage = "Permission denied"
                    hasTestNotificationSucceeded = false
                    isSendingTestNotification = false
                    return
                }
            }

            // Send test notification
            try await container.notificationService.sendThresholdNotification(
                percentage: 85.0,
                threshold: .warning,
                resetTime: Date().addingTimeInterval(3600)
            )

            testNotificationMessage = "Test notification sent!"
            hasTestNotificationSucceeded = true

            // Clear message after 2 seconds
            Task {
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

// MARK: - Auto-Save Modifier

struct SettingsAutoSaveModifier: ViewModifier {
    @Binding var refreshInterval: Double
    @Binding var isSonnetUsageShown: Bool
    @Binding var iconStyle: IconStyle
    @Binding var hasNotificationsEnabled: Bool
    @Binding var warningThreshold: Double
    @Binding var criticalThreshold: Double
    @Binding var isNotifiedOnReset: Bool
    let container: DIContainer

    func body(content: Content) -> some View {
        content
            .onChange(of: refreshInterval) { _, _ in saveSettings() }
            .onChange(of: isSonnetUsageShown) { _, _ in saveSettings() }
            .onChange(of: iconStyle) { _, newValue in
                // Clear preview on actual selection change
                NotificationCenter.default.post(name: .iconStylePreviewChanged, object: nil)
                saveSettings()
            }
            .onChange(of: hasNotificationsEnabled) { _, newValue in
                if newValue {
                    requestNotificationPermission()
                }
                saveSettings()
            }
            .onChange(of: warningThreshold) { _, _ in saveSettings() }
            .onChange(of: criticalThreshold) { _, _ in saveSettings() }
            .onChange(of: isNotifiedOnReset) { _, _ in saveSettings() }
    }

    private func saveSettings() {
        Task {
            var settings = await container.settingsRepository.load()
            settings.refreshInterval = refreshInterval
            settings.isSonnetUsageShown = isSonnetUsageShown
            settings.iconStyle = iconStyle
            settings.hasNotificationsEnabled = hasNotificationsEnabled
            settings.notificationThresholds = NotificationThresholds(
                warningThreshold: warningThreshold,
                criticalThreshold: criticalThreshold,
                isNotifiedOnReset: isNotifiedOnReset
            )

            try? await container.settingsRepository.save(settings)
            NotificationCenter.default.post(name: .settingsDidChange, object: nil)
        }
    }

    private func requestNotificationPermission() {
        Task {
            let hasPermission = await container.notificationService.checkNotificationPermissions()
            if !hasPermission {
                _ = try? await container.notificationService.requestAuthorization()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView(container: DIContainer.shared)
}
