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

    /// Model-scoped limits the user has opted into showing, by API display name.
    /// Empty by default: nothing appears in the popover until the user asks for it.
    var shownScopedModels: Set<String>

    /// Menu bar icon display style
    var iconStyle: IconStyle

    /// Whether menu bar icons are shown in color instead of monochrome.
    var isColoredIcon: Bool

    static let `default` = AppSettings(
        refreshInterval: 60,
        hasNotificationsEnabled: true,
        notificationThresholds: .default,
        isFirstLaunch: true,
        cachedOrganizationId: nil,
        shownScopedModels: [],
        iconStyle: .battery,
        isColoredIcon: true
    )

    enum CodingKeys: String, CodingKey {
        case refreshInterval = "refresh_interval"
        case hasNotificationsEnabled = "notifications_enabled"
        case notificationThresholds = "notification_thresholds"
        case isFirstLaunch = "is_first_launch"
        case cachedOrganizationId = "cached_organization_id"
        case shownScopedModels = "shown_scoped_models"
        case iconStyle = "icon_style"
        case isColoredIcon = "is_colored_icon"
    }

    /// Read-only: migrates settings saved before `shownScopedModels` existed.
    /// Kept out of `CodingKeys` so `encode` stays synthesized.
    private enum LegacyCodingKeys: String, CodingKey {
        case showSonnetUsage = "show_sonnet_usage"
    }
}

extension AppSettings {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings.default

        refreshInterval = try container.decodeIfPresent(TimeInterval.self, forKey: .refreshInterval) ?? defaults.refreshInterval
        hasNotificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .hasNotificationsEnabled) ?? defaults.hasNotificationsEnabled
        notificationThresholds = try container.decodeIfPresent(NotificationThresholds.self, forKey: .notificationThresholds) ?? defaults.notificationThresholds
        isFirstLaunch = try container.decodeIfPresent(Bool.self, forKey: .isFirstLaunch) ?? defaults.isFirstLaunch
        cachedOrganizationId = try container.decodeIfPresent(UUID.self, forKey: .cachedOrganizationId)
        iconStyle = try container.decodeIfPresent(IconStyle.self, forKey: .iconStyle) ?? defaults.iconStyle
        isColoredIcon = try container.decodeIfPresent(Bool.self, forKey: .isColoredIcon) ?? defaults.isColoredIcon

        if let shown = try container.decodeIfPresent(Set<String>.self, forKey: .shownScopedModels) {
            shownScopedModels = shown
        } else {
            let legacy = try decoder.container(keyedBy: LegacyCodingKeys.self)
            let wasSonnetShown = try legacy.decodeIfPresent(Bool.self, forKey: .showSonnetUsage) ?? false
            shownScopedModels = wasSonnetShown ? ["Sonnet"] : defaults.shownScopedModels
        }
    }
}

extension AppSettings {
    /// Validate refresh interval is within bounds
    mutating func setRefreshInterval(_ interval: TimeInterval) {
        refreshInterval = max(60, min(600, interval))
    }

    /// Whether a model-scoped limit should appear in the popover
    func isScopedModelShown(_ name: String) -> Bool {
        shownScopedModels.contains(name)
    }

    mutating func setScopedModel(_ name: String, isShown: Bool) {
        if isShown {
            shownScopedModels.insert(name)
        } else {
            shownScopedModels.remove(name)
        }
    }
}
