//
//  NotificationThresholds.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-14.
//

import Foundation

/// Notification threshold configuration
struct NotificationThresholds: Codable, Equatable, Sendable {
    /// Percentage for warning notification
    var warningThreshold: Double

    /// Percentage for critical notification
    var criticalThreshold: Double

    /// Whether to notify on session reset
    var isNotifiedOnReset: Bool

    static let `default` = NotificationThresholds(
        warningThreshold: Constants.Thresholds.Notification.warningDefault,
        criticalThreshold: Constants.Thresholds.Notification.criticalDefault,
        isNotifiedOnReset: true
    )

    enum CodingKeys: String, CodingKey {
        case warningThreshold = "warning_threshold"
        case criticalThreshold = "critical_threshold"
        case isNotifiedOnReset = "notify_on_reset"
    }
}

extension NotificationThresholds {
    /// Get all enabled thresholds sorted ascending
    var enabledThresholds: [Double] {
        [warningThreshold, criticalThreshold].sorted()
    }
}
