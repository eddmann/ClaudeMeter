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

    @Published var sessionKey: String = ""
    @Published var refreshInterval: Double = 60
    @Published var notificationsEnabled: Bool = true
    @Published var warningThreshold: Double = 75
    @Published var criticalThreshold: Double = 90
    @Published var notifyOnReset: Bool = true
    @Published var showOpusUsage: Bool = false

    @Published var isValidating: Bool = false
    @Published var validationMessage: String?
    @Published var validationSuccess: Bool = false
    @Published var isSaving: Bool = false
    @Published var errorMessage: String?
    @Published var isLoadingSettings: Bool = true

    @Published var showSessionKey: Bool = false

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
            self.notifyOnReset = settings.notificationThresholds.notifyOnReset
            self.showOpusUsage = settings.showOpusUsage

            // Check actual system notification permissions and sync with settings
            let hasSystemPermission = await notificationService.checkNotificationPermissions()
            self.notificationsEnabled = settings.notificationsEnabled && hasSystemPermission

            // If settings say enabled but system permission is denied, clear error and allow re-enabling
            if settings.notificationsEnabled && !hasSystemPermission {
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
            validationMessage = "Session key cannot be empty"
            validationSuccess = false
            return
        }

        isValidating = true
        validationMessage = nil
        validationSuccess = false
        errorMessage = nil

        do {
            // Validate format
            let key = try SessionKey(sessionKey)

            // Validate with Claude API
            let isValid = try await usageService.validateSessionKey(key)

            if isValid {
                validationMessage = "Session key is valid"
                validationSuccess = true
            } else {
                validationMessage = "Session key validation failed"
                validationSuccess = false
            }
        } catch let error as SessionKeyError {
            validationMessage = error.localizedDescription
            validationSuccess = false
        } catch {
            validationMessage = "Validation failed: \(error.localizedDescription)"
            validationSuccess = false
        }

        isValidating = false
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
            if notificationsEnabled {
                let hasPermission = await notificationService.checkNotificationPermissions()
                if !hasPermission {
                    do {
                        let granted = try await notificationService.requestAuthorization()
                        if !granted {
                            errorMessage = "Notifications disabled. Open System Settings > Notifications > ClaudeMeter to enable."
                            isSaving = false
                            // Don't return - save other settings anyway
                            notificationsEnabled = false // Reflect actual state
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
            settings.notificationsEnabled = notificationsEnabled
            settings.notificationThresholds = NotificationThresholds(
                warningThreshold: warningThreshold,
                criticalThreshold: criticalThreshold,
                notifyOnReset: notifyOnReset
            )
            settings.showOpusUsage = showOpusUsage

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
        showSessionKey.toggle()
    }

    /// Open System Settings to Notifications pane
    func openSystemNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Send test notification
    func sendTestNotification() async {
        do {
            // Check if we have permission first
            let hasPermission = await notificationService.checkNotificationPermissions()
            if !hasPermission {
                let granted = try await notificationService.requestAuthorization()
                if !granted {
                    validationMessage = "Notification permission denied"
                    validationSuccess = false
                    return
                }
            }

            // Send test notification
            try await notificationService.sendThresholdNotification(
                percentage: 85.0,
                threshold: .warning,
                resetTime: Date().addingTimeInterval(3600)
            )

            validationMessage = "Test notification sent!"
            validationSuccess = true
        } catch {
            validationMessage = "Failed to send test notification"
            validationSuccess = false
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let settingsDidChange = Notification.Name("settingsDidChange")
}
