//
//  SettingsViewModel.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-14.
//

import Foundation
import Combine
import AppKit

/// ViewModel for settings management
@MainActor
final class SettingsViewModel: ObservableObject {
    // MARK: - Published Properties

    // Session Key
    @Published var sessionKey: String = ""
    @Published var isSessionKeyShown: Bool = false
    @Published var isValidatingSessionKey: Bool = false
    @Published var sessionKeyValidationMessage: String?
    @Published var hasSessionKeyValidationSucceeded: Bool = false

    // Display Settings
    @Published var refreshInterval: Double = 60
    @Published var isSonnetUsageShown: Bool = false
    @Published var iconStyle: IconStyle = .battery

    /// Original icon style for reverting on cancel
    private var originalIconStyle: IconStyle = .battery

    // Notification Settings
    @Published var hasNotificationsEnabled: Bool = true
    @Published var warningThreshold: Double = Constants.Thresholds.Notification.warningDefault
    @Published var criticalThreshold: Double = Constants.Thresholds.Notification.criticalDefault
    @Published var isNotifiedOnReset: Bool = true
    @Published var isSendingTestNotification: Bool = false
    @Published var testNotificationMessage: String?
    @Published var hasTestNotificationSucceeded: Bool = false

    // General State
    @Published var isLoadingSettings: Bool = true
    @Published var isSaving: Bool = false
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let keychainRepository: KeychainRepositoryProtocol
    private let settingsRepository: SettingsRepositoryProtocol
    private let usageService: UsageServiceProtocol
    private let notificationService: NotificationServiceProtocol

    // MARK: - Initialization

    init(
        keychainRepository: KeychainRepositoryProtocol,
        settingsRepository: SettingsRepositoryProtocol,
        usageService: UsageServiceProtocol,
        notificationService: NotificationServiceProtocol
    ) {
        self.keychainRepository = keychainRepository
        self.settingsRepository = settingsRepository
        self.usageService = usageService
        self.notificationService = notificationService

        Task {
            await loadSettings()
        }
    }

    // MARK: - Public Methods

    /// Load current settings
    func loadSettings() async {
        isLoadingSettings = true

        do {
            // Load app settings
            let settings = await settingsRepository.load()
            self.refreshInterval = settings.refreshInterval
            self.warningThreshold = settings.notificationThresholds.warningThreshold
            self.criticalThreshold = settings.notificationThresholds.criticalThreshold
            self.isNotifiedOnReset = settings.notificationThresholds.isNotifiedOnReset
            self.isSonnetUsageShown = settings.isSonnetUsageShown
            self.iconStyle = settings.iconStyle
            self.originalIconStyle = settings.iconStyle

            // Check actual system notification permissions and sync with settings
            let hasSystemPermission = await notificationService.checkNotificationPermissions()
            self.hasNotificationsEnabled = settings.hasNotificationsEnabled && hasSystemPermission

            // If settings say enabled but system permission is denied, clear error and allow re-enabling
            if settings.hasNotificationsEnabled && !hasSystemPermission {
                errorMessage = nil
            }

            // Load session key from keychain
            if let keyString = try? await keychainRepository.retrieve(account: "default") {
                self.sessionKey = keyString
            }
        }

        isLoadingSettings = false
    }

    /// Validate session key before saving
    func validateSessionKey() async {
        guard !sessionKey.isEmpty else {
            sessionKeyValidationMessage = "Session key cannot be empty"
            hasSessionKeyValidationSucceeded = false
            return
        }

        isValidatingSessionKey = true
        sessionKeyValidationMessage = nil
        hasSessionKeyValidationSucceeded = false
        errorMessage = nil

        do {
            // Validate format
            let key = try SessionKey(sessionKey)

            // Validate with Claude API
            let isValid = try await usageService.validateSessionKey(key)

            if isValid {
                sessionKeyValidationMessage = "Session key is valid"
                hasSessionKeyValidationSucceeded = true

                // Clear success message after 3 seconds
                Task {
                    try await Task.sleep(nanoseconds: 3_000_000_000)
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

    /// Save settings
    func saveSettings() async {
        isSaving = true
        errorMessage = nil

        do {
            // Validate thresholds
            if criticalThreshold <= warningThreshold {
                errorMessage = "Critical threshold must be higher than warning threshold"
                isSaving = false
                return
            }

            // Save session key to keychain if changed
            if !sessionKey.isEmpty {
                let key = try SessionKey(sessionKey)
                try await keychainRepository.save(sessionKey: key.value, account: "default")
            }

            // Request notification authorization if enabling notifications
            if hasNotificationsEnabled {
                let hasPermission = await notificationService.checkNotificationPermissions()
                if !hasPermission {
                    do {
                        let granted = try await notificationService.requestAuthorization()
                        if !granted {
                            errorMessage = "Notifications disabled. Open System Settings > Notifications > ClaudeMeter to enable."
                            isSaving = false
                            // Don't return - save other settings anyway
                            hasNotificationsEnabled = false // Reflect actual state
                        }
                    } catch {
                        errorMessage = "Failed to request notification permission: \(error.localizedDescription)"
                        isSaving = false
                        return
                    }
                }
            }

            // Create updated settings
            var settings = await settingsRepository.load()
            settings.refreshInterval = refreshInterval
            settings.hasNotificationsEnabled = hasNotificationsEnabled
            settings.notificationThresholds = NotificationThresholds(
                warningThreshold: warningThreshold,
                criticalThreshold: criticalThreshold,
                isNotifiedOnReset: isNotifiedOnReset
            )
            settings.isSonnetUsageShown = isSonnetUsageShown
            settings.iconStyle = iconStyle

            // Save to repository
            try await settingsRepository.save(settings)

            // Post notification for settings change
            NotificationCenter.default.post(name: .settingsDidChange, object: nil)

            isSaving = false
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }

    /// Toggle session key visibility
    func toggleSessionKeyVisibility() {
        isSessionKeyShown.toggle()
    }

    /// Open System Settings to Notifications pane
    func openSystemNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Send test notification
    func sendTestNotification() async {
        isSendingTestNotification = true
        testNotificationMessage = nil
        hasTestNotificationSucceeded = false

        do {
            // Check if we have permission first
            let hasPermission = await notificationService.checkNotificationPermissions()
            if !hasPermission {
                let granted = try await notificationService.requestAuthorization()
                if !granted {
                    testNotificationMessage = "Notification permission denied. Open System Settings > Notifications > ClaudeMeter to enable."
                    hasTestNotificationSucceeded = false
                    isSendingTestNotification = false
                    return
                }
            }

            // Send test notification
            try await notificationService.sendThresholdNotification(
                percentage: 85.0,
                threshold: .warning,
                resetTime: Date().addingTimeInterval(3600)
            )

            testNotificationMessage = "Test notification sent!"
            hasTestNotificationSucceeded = true

            // Clear message after 3 seconds
            Task {
                try await Task.sleep(nanoseconds: 3_000_000_000)
                testNotificationMessage = nil
                hasTestNotificationSucceeded = false
            }
        } catch {
            testNotificationMessage = "Failed to send test notification: \(error.localizedDescription)"
            hasTestNotificationSucceeded = false
        }

        isSendingTestNotification = false
    }

    /// Preview icon style in menu bar (live preview without saving)
    func previewIconStyle(_ style: IconStyle) {
        NotificationCenter.default.post(name: .iconStylePreviewChanged, object: style)
    }

    /// Revert icon style preview to original (call on cancel)
    func revertIconStylePreview() {
        iconStyle = originalIconStyle
        // Post nil to clear preview and revert to saved style
        NotificationCenter.default.post(name: .iconStylePreviewChanged, object: nil)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let settingsDidChange = Notification.Name("settingsDidChange")
    static let iconStylePreviewChanged = Notification.Name("iconStylePreviewChanged")
}
