//
//  AppSettings.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-14.
//

import Foundation

/// User preferences and app configuration
struct AppSettings: Codable, Equatable, Sendable {
    /// Refresh interval in seconds (60-600)
    var refreshInterval: TimeInterval

    /// Whether notifications are enabled
    var hasNotificationsEnabled: Bool

    /// Notification thresholds
    var notificationThresholds: NotificationThresholds

    /// Whether this is first launch
    var isFirstLaunch: Bool

    /// Last known organization ID (cached)
    var cachedOrganizationId: UUID?

    /// Whether to show Sonnet usage in the popover
    var isSonnetUsageShown: Bool

    /// Menu bar icon display style
    var iconStyle: IconStyle

    static let `default` = AppSettings(
        refreshInterval: 60,
        hasNotificationsEnabled: true,
        notificationThresholds: .default,
        isFirstLaunch: true,
        cachedOrganizationId: nil,
        isSonnetUsageShown: false,
        iconStyle: .battery
    )

    enum CodingKeys: String, CodingKey {
        case refreshInterval = "refresh_interval"
        case hasNotificationsEnabled = "notifications_enabled"
        case notificationThresholds = "notification_thresholds"
        case isFirstLaunch = "is_first_launch"
        case cachedOrganizationId = "cached_organization_id"
        case isSonnetUsageShown = "show_sonnet_usage"
        case iconStyle = "icon_style"
    }
}

extension AppSettings {
    /// Validate refresh interval is within bounds
    mutating func setRefreshInterval(_ interval: TimeInterval) {
        refreshInterval = max(60, min(600, interval))
    }
}
