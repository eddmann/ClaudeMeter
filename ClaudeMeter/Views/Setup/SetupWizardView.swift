//
//  SetupWizardView.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-14.
//

import SwiftUI
import AppKit

/// Setup wizard view for initial configuration
struct SetupWizardView: View {
    @ObservedObject var viewModel: SetupViewModel

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                if let appIcon = NSImage(named: NSImage.applicationIconName) {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 64, height: 64)
                } else {
                    Image(systemName: "gauge.with.dots.needle.67percent")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                }

                Text("Welcome to ClaudeMeter")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Monitor your Claude.ai plan usage in real-time")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 32)

            // Session Key Input
            VStack(alignment: .leading, spacing: 8) {
                Text("Claude Session Key")
                    .font(.headline)

                SecureField("sk-ant-...", text: $viewModel.sessionKeyInput)
                    .textFieldStyle(.roundedBorder)
                    .disabled(viewModel.isValidating)
                    .accessibilityLabel("Session key input field")
                    .accessibilityHint("Enter your Claude session key starting with sk-ant-")

                Text("Find your session key in Claude.ai browser cookies")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Format validation indicator
                if !viewModel.sessionKeyInput.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.isFormatValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(viewModel.isFormatValid ? .green : .red)
                        Text(viewModel.isFormatValid ? "Format valid" : "Invalid format (must start with sk-ant-)")
                            .font(.caption)
                            .foregroundColor(viewModel.isFormatValid ? .green : .red)
                    }
                }
            }
            .padding(.horizontal, 32)

            // Error Message
            if let errorMessage = viewModel.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundColor(.orange)
                }
                .padding(12)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal, 32)
                .accessibilityLabel("Error: \(errorMessage)")
            }

            // Success Message
            if viewModel.validationSuccess {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Setup complete! Launching ClaudeMeter...")
                        .font(.callout)
                        .foregroundColor(.green)
                }
                .padding(12)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal, 32)
            }

            Spacer()

            // Continue Button
            Button(action: {
                Task {
                    await viewModel.validateAndSave()
                }
            }) {
                HStack {
                    Text(viewModel.isValidating ? "Validating..." : "Continue")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .allowsHitTesting(viewModel.isFormatValid && !viewModel.isValidating)
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
            .accessibilityLabel(viewModel.isValidating ? "Validating session key" : "Continue with setup")
            .accessibilityHint("Validates your session key and completes setup")
        }
        .frame(width: 500, height: 400)
    }
}

#Preview("Empty State") {
    SetupWizardView(viewModel: SetupViewModel(
        keychainRepository: StubKeychainRepository(),
        usageService: StubUsageService(),
        settingsRepository: StubSettingsRepository()
    ))
}

#Preview("With Input") {
    let viewModel = SetupViewModel(
        keychainRepository: StubKeychainRepository(),
        usageService: StubUsageService(),
        settingsRepository: StubSettingsRepository()
    )
    viewModel.sessionKeyInput = "sk-ant-api03-abc123"
    return SetupWizardView(viewModel: viewModel)
}

#Preview("Validating") {
    let viewModel = SetupViewModel(
        keychainRepository: StubKeychainRepository(),
        usageService: StubUsageService(),
        settingsRepository: StubSettingsRepository()
    )
    viewModel.sessionKeyInput = "sk-ant-api03-abc123"
    viewModel.isValidating = true
    return SetupWizardView(viewModel: viewModel)
}

#Preview("Error State") {
    let viewModel = SetupViewModel(
        keychainRepository: StubKeychainRepository(),
        usageService: StubUsageService(),
        settingsRepository: StubSettingsRepository()
    )
    viewModel.errorMessage = "Session key is invalid or expired"
    return SetupWizardView(viewModel: viewModel)
}

// MARK: - Preview Stubs

private actor StubKeychainRepository: KeychainRepositoryProtocol {
    func save(sessionKey: String, account: String) async throws {}
    func retrieve(account: String) async throws -> String { "" }
    func update(sessionKey: String, account: String) async throws {}
    func delete(account: String) async throws {}
    func exists(account: String) async -> Bool { false }
}

private actor StubUsageService: UsageServiceProtocol {
    func fetchUsage(forceRefresh: Bool) async throws -> UsageData {
        let stubLimit = UsageLimit(
            tokensUsed: 0,
            tokensLimit: 100,
            resetAt: Date().addingTimeInterval(3600)
        )
        return UsageData(
            sessionUsage: stubLimit,
            weeklyUsage: stubLimit,
            opusUsage: nil,
            lastUpdated: Date(),
            timezone: .current
        )
    }
    func fetchOrganizations() async throws -> [Organization] { [] }
    func fetchOrganizations(sessionKey: SessionKey) async throws -> [Organization] { [] }
    func validateSessionKey(_ sessionKey: SessionKey) async throws -> Bool { true }
}

private actor StubSettingsRepository: SettingsRepositoryProtocol {
    func load() async -> AppSettings {
        await AppSettings(
            refreshInterval: 60,
            notificationsEnabled: false,
            notificationThresholds: .default,
            isFirstLaunch: true,
            cachedOrganizationId: nil,
            showOpusUsage: false
        )
    }
    func save(_ settings: AppSettings) async throws {}
    func loadNotificationState() async -> NotificationState {
        await NotificationState()
    }
    func saveNotificationState(_ state: NotificationState) async throws {}
}
