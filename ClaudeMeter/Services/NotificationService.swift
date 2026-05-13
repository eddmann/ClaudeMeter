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
    private var center: UserNotificationCenterProtocol
    private let settingsRepository: SettingsRepositoryProtocol

    init(
        settingsRepository: SettingsRepositoryProtocol,
        notificationCenter: UserNotificationCenterProtocol = UNUserNotificationCenter.current()
    ) {
        self.settingsRepository = settingsRepository
        self.center = notificationCenter
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

    /// Evaluate usage thresholds and send notifications
    func evaluateThresholds(
        accountLabel: String,
        usageData: UsageData,
        settings: AppSettings
    ) async {
        let thresholds = settings.notificationThresholds
        let percentage = usageData.sessionUsage.percentage
        let resetTime = usageData.sessionUsage.resetAt

        var state = await settingsRepository.loadNotificationState()
        let hasPermission = await checkNotificationPermissions()
        let isNotificationEnabled = settings.hasNotificationsEnabled && hasPermission

        let shouldNotifyWarning = state.shouldNotify(
            currentPercentage: percentage,
            threshold: thresholds.warningThreshold,
            isWarning: true
        )
        let shouldNotifyCritical = state.shouldNotify(
            currentPercentage: percentage,
            threshold: thresholds.criticalThreshold,
            isWarning: false
        )
        let shouldNotifyReset = isNotificationEnabled
            && thresholds.isNotifiedOnReset
            && state.shouldNotifyReset(currentPercentage: percentage)

        if isNotificationEnabled && shouldNotifyWarning {
            try? await sendThresholdNotification(
                accountLabel: accountLabel,
                percentage: percentage,
                threshold: .warning,
                resetTime: resetTime
            )
            state.hasWarningBeenNotified = true
        }

        if isNotificationEnabled && shouldNotifyCritical {
            try? await sendThresholdNotification(
                accountLabel: accountLabel,
                percentage: percentage,
                threshold: .critical,
                resetTime: resetTime
            )
            state.hasCriticalBeenNotified = true
        }

        if shouldNotifyReset {
            try? await sendResetNotification(accountLabel: accountLabel)
        }

        if percentage < thresholds.warningThreshold {
            state.hasWarningBeenNotified = false
        }
        if percentage < thresholds.criticalThreshold {
            state.hasCriticalBeenNotified = false
        }

        state.lastPercentage = percentage
        try? await settingsRepository.saveNotificationState(state)
    }

    /// Send threshold notification
    func sendThresholdNotification(
        accountLabel: String?,
        percentage: Double,
        threshold: UsageThresholdType,
        resetTime: Date
    ) async throws {
        // Check if notifications are enabled
        guard await shouldSendNotifications() else { return }

        let content = UNMutableNotificationContent()
        content.title = prefixTitle(threshold.title, accountLabel: accountLabel)
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
    }

    /// Send session reset notification
    func sendResetNotification(accountLabel: String?) async throws {
        guard await shouldSendNotifications() else { return }

        let content = UNMutableNotificationContent()
        content.title = prefixTitle(UsageThresholdType.reset.title, accountLabel: accountLabel)
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

    /// Check system notification permissions
    func checkNotificationPermissions() async -> Bool {
        await center.authorizationStatus() == .authorized
    }

    // MARK: - Private Methods

    /// Prefix a notification title with the account label when one is provided, so multi-account
    /// users see which account the alert refers to (e.g. "Client X — Session Reset"). When nil
    /// the bare title is used — for test notifications and any global / not-account-scoped alert.
    private func prefixTitle(_ title: String, accountLabel: String?) -> String {
        guard let label = accountLabel?.trimmingCharacters(in: .whitespaces), !label.isEmpty else {
            return title
        }
        return "\(label) — \(title)"
    }

    private func shouldSendNotifications() async -> Bool {
        let systemPermission = await checkNotificationPermissions()
        let settings = await settingsRepository.load()
        return systemPermission && settings.hasNotificationsEnabled
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        NotificationCenter.default.post(name: .openUsagePopover, object: nil)
        completionHandler()
    }
}

extension Notification.Name {
    static let openUsagePopover = Notification.Name("openUsagePopover")
}
