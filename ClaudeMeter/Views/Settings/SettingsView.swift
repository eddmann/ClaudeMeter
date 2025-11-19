//
//  SettingsView.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-14.
//

import SwiftUI

/// Settings window view
struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Show loading state while settings are being loaded
            if viewModel.isLoadingSettings {
                VStack {
                    Spacer()
                    ProgressView("Loading settings...")
                        .controlSize(.large)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                settingsContent
            }
        }
        .frame(width: 500, height: 540)
        .onAppear {
            Task {
                await viewModel.loadSettings()
            }
        }
    }

    // MARK: - Settings Content

    private var settingsContent: some View {
        VStack(spacing: 0) {
            // Content
            Form {
                // Session Key Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Session Key")
                            .font(.headline)
                        
                        Text("Your Claude.ai session key authenticates API requests. Find this in your browser's cookies.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack {
                            if viewModel.showSessionKey {
                                TextField("sk-ant-...", text: $viewModel.sessionKey)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))
                                    .labelsHidden()
                                    .accessibilityLabel("Session key input")
                                    
                            } else {
                                SecureField("sk-ant-...", text: $viewModel.sessionKey)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))
                                    .labelsHidden()
                                    .accessibilityLabel("Session key input (masked)")
                            }

                            Button(action: {
                                viewModel.toggleSessionKeyVisibility()
                            }) {
                                Image(systemName: viewModel.showSessionKey ? "eye.slash" : "eye")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(viewModel.showSessionKey ? "Hide session key" : "Show session key")
                        }

                        HStack {
                            Button("Validate") {
                                Task {
                                    await viewModel.validateSessionKey()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(viewModel.isValidating || viewModel.sessionKey.isEmpty)
                            .accessibilityLabel("Validate session key")

                            if viewModel.isValidating {
                                ProgressView()
                                    .scaleEffect(0.5)
                            }

                            // Validation status
                            if let message = viewModel.validationMessage {
                                HStack(spacing: 4) {
                                    Image(systemName: viewModel.validationSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(viewModel.validationSuccess ? .green : .red)
                                    Text(message)
                                        .font(.caption)
                                        .foregroundColor(viewModel.validationSuccess ? .green : .red)
                                }
                                .accessibilityLabel("Validation status: \(message)")
                            }

                            Spacer()
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Authentication")
                }

                // Display Settings Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Refresh Interval")
                            Spacer()

                            Picker("", selection: $viewModel.refreshInterval) {
                                Text("1 minute").tag(60.0)
                                Text("5 minutes").tag(300.0)
                                Text("10 minutes").tag(600.0)
                            }
                            .labelsHidden()
                            .accessibilityLabel("Refresh interval picker")
                            .accessibilityValue(refreshIntervalAccessibilityLabel(viewModel.refreshInterval))
                        }

                        Text("Data will refresh every \(refreshIntervalDisplayText(viewModel.refreshInterval))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Show Opus Usage", isOn: $viewModel.showOpusUsage)
                            .accessibilityLabel("Show Opus usage toggle")
                        
                        Text("Display weekly Opus usage in the menu bar popover")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Display")
                }

                // Notification Settings Section
                Section {
                    Toggle("Enable Notifications", isOn: $viewModel.notificationsEnabled)
                        .accessibilityLabel("Enable notifications toggle")

                    if viewModel.notificationsEnabled {
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Warning Threshold")
                                    Spacer()
                                    Text("\(Int(viewModel.warningThreshold))%")
                                        .foregroundColor(.orange)
                                }
                                Slider(value: $viewModel.warningThreshold, in: 50...90, step: 5)
                                    .tint(.orange)
                                    .accessibilityLabel("Warning threshold slider")
                                    .accessibilityValue("\(Int(viewModel.warningThreshold)) percent")
                                Text("Get notified when usage reaches this percentage")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Critical Threshold")
                                    Spacer()
                                    Text("\(Int(viewModel.criticalThreshold))%")
                                        .foregroundColor(.red)
                                }
                                Slider(value: $viewModel.criticalThreshold, in: 75...100, step: 5)
                                    .tint(.red)
                                    .accessibilityLabel("Critical threshold slider")
                                    .accessibilityValue("\(Int(viewModel.criticalThreshold)) percent")
                                Text("Get urgent notification when usage reaches this percentage")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Toggle("Notify on Session Reset", isOn: $viewModel.notifyOnReset)
                                .accessibilityLabel("Notify on session reset toggle")

                            // Test notification button
                            Button("Send Test Notification") {
                                Task {
                                    await viewModel.sendTestNotification()
                                }
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Send test notification")
                        }
                        .padding(.top, 8)
                    }
                } header: {
                    Text("Notifications")
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            // Footer with actions
            HStack {
                if let errorMessage = viewModel.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)

                        // Show "Open Settings" button if it's a notification permission error
                        if errorMessage.contains("System Settings") {
                            Button("Open Settings") {
                                viewModel.openSystemNotificationSettings()
                            }
                            .buttonStyle(.link)
                            .font(.caption)
                        }
                    }
                }

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                .accessibilityLabel("Cancel and close settings")

                Button("Save") {
                    Task {
                        await viewModel.saveSettings()
                        // Only dismiss if save was successful (no error message)
                        if viewModel.errorMessage == nil {
                            dismiss()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isSaving)
                .keyboardShortcut(.return)
                .accessibilityLabel("Save settings and close")

                if viewModel.isSaving {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding()
        }
    }

    // MARK: - Helper Functions

    private func refreshIntervalDisplayText(_ interval: Double) -> String {
        switch interval {
        case 60:
            return "1 minute"
        case 300:
            return "5 minutes"
        case 600:
            return "10 minutes"
        default:
            return "\(Int(interval / 60)) minutes"
        }
    }

    private func refreshIntervalAccessibilityLabel(_ interval: Double) -> String {
        switch interval {
        case 60:
            return "1 minute"
        case 300:
            return "5 minutes"
        case 600:
            return "10 minutes"
        default:
            return "\(Int(interval)) seconds"
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewContainer: View {
        @StateObject private var viewModel = SettingsViewModel(
            keychainRepository: DIContainer.shared.keychainRepository,
            settingsRepository: DIContainer.shared.settingsRepository,
            usageService: DIContainer.shared.usageService,
            notificationService: DIContainer.shared.notificationService
        )

        var body: some View {
            SettingsView(viewModel: viewModel)
        }
    }

    return PreviewContainer()
}
