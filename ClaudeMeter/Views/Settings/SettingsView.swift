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

    @State private var isSendingTestNotification: Bool = false
    @State private var testNotificationMessage: String?
    @State private var hasTestNotificationSucceeded: Bool = false
    @State private var notificationError: String?

    @State private var addAccountSheetPresented: Bool = false
    @State private var editingAccount: ClaudeAccount?
    @State private var pendingRemoval: ClaudeAccount?

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
        .frame(width: 520)
        .onAppear {
            Task { await updateNotificationStatus() }
        }
        .onChange(of: appModel.settings.hasNotificationsEnabled) { _, newValue in
            Task {
                if newValue {
                    await appModel.requestNotificationPermissionIfNeeded()
                }
                await updateNotificationStatus()
            }
        }
        .onChange(of: launchAtLogin) { _, newValue in
            updateLaunchAtLogin(newValue)
        }
        .sheet(isPresented: $addAccountSheetPresented) {
            SetupWizardView(appModel: appModel) {
                addAccountSheetPresented = false
            }
        }
        .sheet(item: $editingAccount) { account in
            EditAccountSheet(
                appModel: appModel,
                account: account,
                onClose: { editingAccount = nil }
            )
        }
        .alert(
            "Remove account?",
            isPresented: Binding(
                get: { pendingRemoval != nil },
                set: { if !$0 { pendingRemoval = nil } }
            ),
            presenting: pendingRemoval
        ) { account in
            Button("Remove", role: .destructive) {
                Task {
                    try? await appModel.removeAccount(account.id)
                    pendingRemoval = nil
                }
            }
            Button("Cancel", role: .cancel) {
                pendingRemoval = nil
            }
        } message: { account in
            Text("\(account.label) will be removed and its session key deleted from the Keychain.")
        }
    }

    // MARK: - General Tab

    private var generalTab: some View {
        ScrollView {
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
                    accountsSection
                    refreshIntervalSection
                    sonnetUsageSection
                    iconStyleSection
                    launchAtLoginSection
                }
            }
            .padding(24)
        }
    }

    // MARK: - Accounts Section

    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Claude Accounts")
                    .font(.subheadline)
                Spacer()
                Button {
                    addAccountSheetPresented = true
                } label: {
                    Label("Add Account", systemImage: "plus")
                }
                .controlSize(.small)
            }

            Text("Each account gets its own menu bar item.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if appModel.settings.accounts.isEmpty {
                HStack {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .foregroundStyle(.secondary)
                    Text("No accounts configured. Click \"Add Account\" to begin.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(appModel.settings.accounts) { account in
                        AccountRow(
                            account: account,
                            onEdit: { editingAccount = account },
                            onRemove: { pendingRemoval = account }
                        )
                    }
                }
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
            Divider().padding(.vertical, 4)
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
                Task { await sendTestNotification() }
            }
            .controlSize(.small)
            .disabled(isSendingTestNotification)
            if isSendingTestNotification {
                ProgressView().controlSize(.small)
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

    private var warningThresholdValue: Double { appModel.settings.notificationThresholds.warningThreshold }
    private var criticalThresholdValue: Double { appModel.settings.notificationThresholds.criticalThreshold }

    // MARK: - About Tab

    private var aboutTab: some View {
        VStack(spacing: 24) {
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
            VStack(spacing: 4) {
                Text("© 2025 Edd Mann")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Monitor your Claude.ai usage limits.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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

    @MainActor
    private func updateNotificationStatus() async {
        let hasPermission = await appModel.checkNotificationPermissions()
        if !hasPermission {
            notificationError = "Notifications disabled in System Settings"
            if appModel.settings.hasNotificationsEnabled {
                appModel.settings.hasNotificationsEnabled = false
            }
        } else {
            notificationError = nil
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
            try await appModel.sendTestNotification()
            testNotificationMessage = "Test notification sent!"
            hasTestNotificationSucceeded = true
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

// MARK: - Account Row

private struct AccountRow: View {
    let account: ClaudeAccount
    let onEdit: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.tertiary)
                    .frame(width: 28, height: 28)
                Text(account.menuBarInitial)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(account.label)
                    .font(.callout)
                    .fontWeight(.medium)
                if let orgId = account.organizationId {
                    Text("org: \(orgId.uuidString.prefix(8))…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button("Edit", action: onEdit)
                .controlSize(.small)
            Button(role: .destructive, action: onRemove) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Remove account")
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Edit Account Sheet

private struct EditAccountSheet: View {
    @Bindable var appModel: AppModel
    let account: ClaudeAccount
    let onClose: () -> Void

    @State private var labelInput: String
    @State private var sessionKeyInput: String = ""
    @State private var isSessionKeyShown: Bool = false
    @State private var isValidating: Bool = false
    @State private var statusMessage: String?
    @State private var hasSucceeded: Bool = false

    init(appModel: AppModel, account: ClaudeAccount, onClose: @escaping () -> Void) {
        self.appModel = appModel
        self.account = account
        self.onClose = onClose
        _labelInput = State(initialValue: account.label)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit Account")
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 6) {
                Text("Label").font(.subheadline)
                TextField("Label", text: $labelInput)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Replace Session Key (optional)").font(.subheadline)
                Text("Leave blank to keep the existing key.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    if isSessionKeyShown {
                        TextField("sk-ant-...", text: $sessionKeyInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    } else {
                        SecureField("sk-ant-...", text: $sessionKeyInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }
                    Button(action: { isSessionKeyShown.toggle() }) {
                        Image(systemName: isSessionKeyShown ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                }
            }

            if let message = statusMessage {
                Label(message, systemImage: hasSucceeded ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(hasSucceeded ? .green : .red)
                    .font(.caption)
            }

            Spacer()

            HStack {
                Button("Cancel") { onClose() }
                Spacer()
                Button("Save") {
                    Task { await save() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isValidating)
            }
        }
        .padding(20)
        .frame(width: 420, height: 320)
    }

    @MainActor
    private func save() async {
        isValidating = true
        statusMessage = nil
        hasSucceeded = false

        let trimmedLabel = labelInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedLabel.isEmpty && trimmedLabel != account.label {
            appModel.renameAccount(account.id, label: trimmedLabel)
        }

        let trimmedKey = sessionKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedKey.isEmpty {
            do {
                let isValid = try await appModel.updateSessionKey(accountId: account.id, trimmedKey)
                if isValid {
                    statusMessage = "Session key updated"
                    hasSucceeded = true
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(500))
                        onClose()
                    }
                    isValidating = false
                    return
                } else {
                    statusMessage = "Session key validation failed"
                }
            } catch {
                statusMessage = error.localizedDescription
            }
        } else {
            // Label-only change.
            onClose()
        }
        isValidating = false
    }
}
