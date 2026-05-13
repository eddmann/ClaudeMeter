//
//  NotificationServiceProtocol.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-14.
//

import Foundation

/// Types of usage threshold notifications
/// Raw values are used for notification identifiers (not the actual threshold percentages)
enum UsageThresholdType: String {
    case warning
    case critical
    case reset

    var title: String {
        switch self {
        case .warning: return "Usage Warning"
        case .critical: return "Critical Usage"
        case .reset: return "Session Reset"
        }
    }

    func body(percentage: Double, resetTime: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let resetString = formatter.localizedString(for: resetTime, relativeTo: Date())

        switch self {
        case .warning:
            return "You've used \(Int(percentage))% of your 5-hour session. Resets \(resetString)"
        case .critical:
            return "Critical: \(Int(percentage))% of session used. Resets \(resetString)"
        case .reset:
            return "Your usage limits have been reset. Fresh capacity available!"
        }
    }
}

/// Protocol for notification operations
@MainActor
protocol NotificationServiceProtocol {
    /// Setup notification center delegate
    func setupDelegate()

    /// Request notification authorization from the user
    func requestAuthorization() async throws -> Bool

    /// Evaluate thresholds and send notifications for new usage data
    func evaluateThresholds(
        accountLabel: String,
        usageData: UsageData,
        settings: AppSettings
    ) async

    /// Send threshold notification. When `accountLabel` is non-nil, the title is prefixed with
    /// the label (e.g. "Client X — Usage Warning") so multi-account users see which account
    /// the alert refers to. Pass nil for global/test notifications.
    func sendThresholdNotification(
        accountLabel: String?,
        percentage: Double,
        threshold: UsageThresholdType,
        resetTime: Date
    ) async throws

    /// Send session reset notification. `accountLabel` is prefixed to the title when non-nil.
    func sendResetNotification(accountLabel: String?) async throws

    /// Check system notification permissions
    func checkNotificationPermissions() async -> Bool
}
