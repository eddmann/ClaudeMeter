//
//  NotificationService.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-14.
//

import Foundation
import UserNotifications

/// Main actor-isolated notification service
@MainActor
final class NotificationService: NSObject, NotificationServiceProtocol, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    private let settingsRepository: SettingsRepositoryProtocol
    private var notificationTracker: [UsageThresholdType: Bool] = [:]

    init(settingsRepository: SettingsRepositoryProtocol) {
        self.settingsRepository = settingsRepository
        super.init()
    }

    /// Setup notification center delegate
    func setupDelegate() {
        center.delegate = self
    }

    /// Request notification authorization from the user
    func requestAuthorization() async throws -> Bool {
        let granted = try await center.requestAuthorization(options: [.alert, .sound])
        return granted
    }

    /// Send threshold notification
    func sendThresholdNotification(
        percentage: Double,
        threshold: UsageThresholdType,
        resetTime: Date
    ) async throws {
        // Check if notifications are enabled
        guard await shouldSendNotifications() else { return }

        // Prevent duplicate notifications for same threshold
        guard notificationTracker[threshold] != true else { return }

        let content = UNMutableNotificationContent()
        content.title = threshold.title
        content.body = threshold.body(percentage: percentage, resetTime: resetTime)
        content.sound = threshold == .critical ? .defaultCritical : .default
        content.categoryIdentifier = "usage.threshold"
        content.userInfo = ["threshold": threshold.rawValue, "percentage": percentage]

        let request = UNNotificationRequest(
            identifier: "threshold.\(threshold.rawValue).\(UUID())",
            content: content,
            trigger: nil // Deliver immediately
        )

        try await center.add(request)
        notificationTracker[threshold] = true

        // Save notification state to persistence
        var state = await settingsRepository.loadNotificationState()
        if threshold == .warning {
            state.warningNotified = true
        } else if threshold == .critical {
            state.criticalNotified = true
        }
        try? await settingsRepository.saveNotificationState(state)
    }

    /// Send session reset notification
    func sendResetNotification() async throws {
        guard await shouldSendNotifications() else { return }

        let content = UNMutableNotificationContent()
        content.title = UsageThresholdType.reset.title
        content.body = UsageThresholdType.reset.body(percentage: 0, resetTime: Date())
        content.sound = .default
        content.categoryIdentifier = "usage.reset"

        let request = UNNotificationRequest(
            identifier: "reset.\(UUID())",
            content: content,
            trigger: nil
        )

        try await center.add(request)
    }

    /// Reset threshold tracking
    func resetThresholdTracking(for threshold: UsageThresholdType) async {
        notificationTracker[threshold] = false

        // Update persisted state
        var state = await settingsRepository.loadNotificationState()
        if threshold == .warning {
            state.warningNotified = false
        } else if threshold == .critical {
            state.criticalNotified = false
        }
        try? await settingsRepository.saveNotificationState(state)
    }

    /// Check system notification permissions
    func checkNotificationPermissions() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized
    }

    // MARK: - Private Methods

    private func shouldSendNotifications() async -> Bool {
        let systemPermission = await checkNotificationPermissions()
        let settings = await settingsRepository.load()
        return systemPermission && settings.notificationsEnabled
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Handle notification tap - open popover
        NotificationCenter.default.post(
            name: .openUsagePopover,
            object: nil
        )
        completionHandler()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openUsagePopover = Notification.Name("openUsagePopover")
}
