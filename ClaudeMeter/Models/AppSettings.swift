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

    /// Configured Claude.ai accounts. Multi-account: each has its own keychain entry and menu bar item.
    var accounts: [ClaudeAccount]

    /// Whether to show Sonnet usage in the popover
    var isSonnetUsageShown: Bool

    /// Menu bar icon display style
    var iconStyle: IconStyle

    static let `default` = AppSettings(
        refreshInterval: 60,
        hasNotificationsEnabled: true,
        notificationThresholds: .default,
        isFirstLaunch: true,
        accounts: [],
        isSonnetUsageShown: false,
        iconStyle: .battery
    )

    enum CodingKeys: String, CodingKey {
        case refreshInterval = "refresh_interval"
        case hasNotificationsEnabled = "notifications_enabled"
        case notificationThresholds = "notification_thresholds"
        case isFirstLaunch = "is_first_launch"
        case accounts
        case isSonnetUsageShown = "show_sonnet_usage"
        case iconStyle = "icon_style"
        // Legacy keys, decoded only for migration
        case legacyCachedOrganizationId = "cached_organization_id"
    }

    init(
        refreshInterval: TimeInterval,
        hasNotificationsEnabled: Bool,
        notificationThresholds: NotificationThresholds,
        isFirstLaunch: Bool,
        accounts: [ClaudeAccount],
        isSonnetUsageShown: Bool,
        iconStyle: IconStyle
    ) {
        self.refreshInterval = refreshInterval
        self.hasNotificationsEnabled = hasNotificationsEnabled
        self.notificationThresholds = notificationThresholds
        self.isFirstLaunch = isFirstLaunch
        self.accounts = accounts
        self.isSonnetUsageShown = isSonnetUsageShown
        self.iconStyle = iconStyle
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings.default
        refreshInterval = try container.decodeIfPresent(TimeInterval.self, forKey: .refreshInterval) ?? defaults.refreshInterval
        hasNotificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .hasNotificationsEnabled) ?? defaults.hasNotificationsEnabled
        notificationThresholds = try container.decodeIfPresent(NotificationThresholds.self, forKey: .notificationThresholds) ?? defaults.notificationThresholds
        isFirstLaunch = try container.decodeIfPresent(Bool.self, forKey: .isFirstLaunch) ?? defaults.isFirstLaunch
        isSonnetUsageShown = try container.decodeIfPresent(Bool.self, forKey: .isSonnetUsageShown) ?? defaults.isSonnetUsageShown
        iconStyle = try container.decodeIfPresent(IconStyle.self, forKey: .iconStyle) ?? defaults.iconStyle

        if let decoded = try container.decodeIfPresent([ClaudeAccount].self, forKey: .accounts) {
            accounts = decoded
        } else if let legacyOrgId = try container.decodeIfPresent(UUID.self, forKey: .legacyCachedOrganizationId) {
            // Migrate from single-account schema: synthesize a default account using the cached org id.
            // The session key will be moved out of keychain account "default" at app bootstrap.
            accounts = [ClaudeAccount(label: "Default", organizationId: legacyOrgId)]
        } else {
            accounts = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(refreshInterval, forKey: .refreshInterval)
        try container.encode(hasNotificationsEnabled, forKey: .hasNotificationsEnabled)
        try container.encode(notificationThresholds, forKey: .notificationThresholds)
        try container.encode(isFirstLaunch, forKey: .isFirstLaunch)
        try container.encode(accounts, forKey: .accounts)
        try container.encode(isSonnetUsageShown, forKey: .isSonnetUsageShown)
        try container.encode(iconStyle, forKey: .iconStyle)
    }
}

extension AppSettings {
    /// Validate refresh interval is within bounds
    mutating func setRefreshInterval(_ interval: TimeInterval) {
        refreshInterval = max(60, min(600, interval))
    }

    /// Find an account by id.
    func account(withId id: UUID) -> ClaudeAccount? {
        accounts.first(where: { $0.id == id })
    }
}
