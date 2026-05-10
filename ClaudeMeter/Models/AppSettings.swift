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

    /// Tint the menu bar icon with the green/orange/red status colours. When false (default),
    /// the icon is rendered as a template image so macOS tints it to match the system menu bar
    /// (white in dark mode, black in light mode), aligning with the system tray's aesthetic.
    var useColoredIcon: Bool

    static let `default` = AppSettings(
        refreshInterval: 60,
        hasNotificationsEnabled: true,
        notificationThresholds: .default,
        isFirstLaunch: true,
        cachedOrganizationId: nil,
        isSonnetUsageShown: false,
        iconStyle: .battery,
        useColoredIcon: false
    )

    enum CodingKeys: String, CodingKey {
        case refreshInterval = "refresh_interval"
        case hasNotificationsEnabled = "notifications_enabled"
        case notificationThresholds = "notification_thresholds"
        case isFirstLaunch = "is_first_launch"
        case cachedOrganizationId = "cached_organization_id"
        case isSonnetUsageShown = "show_sonnet_usage"
        case iconStyle = "icon_style"
        case useColoredIcon = "use_colored_icon"
    }

    init(
        refreshInterval: TimeInterval,
        hasNotificationsEnabled: Bool,
        notificationThresholds: NotificationThresholds,
        isFirstLaunch: Bool,
        cachedOrganizationId: UUID?,
        isSonnetUsageShown: Bool,
        iconStyle: IconStyle,
        useColoredIcon: Bool
    ) {
        self.refreshInterval = refreshInterval
        self.hasNotificationsEnabled = hasNotificationsEnabled
        self.notificationThresholds = notificationThresholds
        self.isFirstLaunch = isFirstLaunch
        self.cachedOrganizationId = cachedOrganizationId
        self.isSonnetUsageShown = isSonnetUsageShown
        self.iconStyle = iconStyle
        self.useColoredIcon = useColoredIcon
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings.default
        refreshInterval = try container.decodeIfPresent(TimeInterval.self, forKey: .refreshInterval) ?? defaults.refreshInterval
        hasNotificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .hasNotificationsEnabled) ?? defaults.hasNotificationsEnabled
        notificationThresholds = try container.decodeIfPresent(NotificationThresholds.self, forKey: .notificationThresholds) ?? defaults.notificationThresholds
        isFirstLaunch = try container.decodeIfPresent(Bool.self, forKey: .isFirstLaunch) ?? defaults.isFirstLaunch
        cachedOrganizationId = try container.decodeIfPresent(UUID.self, forKey: .cachedOrganizationId)
        isSonnetUsageShown = try container.decodeIfPresent(Bool.self, forKey: .isSonnetUsageShown) ?? defaults.isSonnetUsageShown
        iconStyle = try container.decodeIfPresent(IconStyle.self, forKey: .iconStyle) ?? defaults.iconStyle
        // Backwards-compat: this key didn't exist before, so fall back to the default (off).
        useColoredIcon = try container.decodeIfPresent(Bool.self, forKey: .useColoredIcon) ?? defaults.useColoredIcon
    }
}

extension AppSettings {
    /// Validate refresh interval is within bounds
    mutating func setRefreshInterval(_ interval: TimeInterval) {
        refreshInterval = max(60, min(600, interval))
    }
}
