//
//  SettingsRepositoryTests.swift
//  ClaudeMeterTests
//
//  Created by Edd on 2026-01-09.
//

import XCTest
@testable import ClaudeMeter

final class SettingsRepositoryTests: XCTestCase {
    func test_settingsPersistAcrossLaunches() async throws {
        let suiteName = "SettingsRepositoryTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)
        defer { userDefaults?.removePersistentDomain(forName: suiteName) }

        let repository = SettingsRepository(userDefaults: userDefaults ?? .standard)

        let account = ClaudeAccount(
            label: "Personal",
            organizationId: UUID(uuidString: TestConstants.organizationUUIDString)
        )
        var settings = AppSettings.default
        settings.refreshInterval = 300
        settings.hasNotificationsEnabled = false
        settings.isFirstLaunch = false
        settings.accounts = [account]
        settings.iconStyle = .segments

        try await repository.save(settings)
        let loaded = await repository.load()

        XCTAssertEqual(loaded, settings)
    }

    func test_legacyCachedOrganizationId_migratesToFirstAccount() async throws {
        let suiteName = "SettingsRepositoryTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)
        defer { userDefaults?.removePersistentDomain(forName: suiteName) }

        // Hand-rolled legacy payload (pre multi-account schema).
        let legacyJSON: [String: Any] = [
            "refresh_interval": 60,
            "notifications_enabled": true,
            "is_first_launch": false,
            "show_sonnet_usage": false,
            "icon_style": "battery",
            "cached_organization_id": TestConstants.organizationUUIDString
        ]
        let data = try JSONSerialization.data(withJSONObject: legacyJSON)
        userDefaults?.set(data, forKey: "app_settings")

        let repository = SettingsRepository(userDefaults: userDefaults ?? .standard)
        let loaded = await repository.load()

        XCTAssertEqual(loaded.accounts.count, 1)
        XCTAssertEqual(loaded.accounts.first?.label, "Default")
        XCTAssertEqual(
            loaded.accounts.first?.organizationId,
            UUID(uuidString: TestConstants.organizationUUIDString)
        )
    }

    func test_notificationStatePersistsAcrossLaunches() async throws {
        let suiteName = "SettingsRepositoryTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)
        defer { userDefaults?.removePersistentDomain(forName: suiteName) }

        let repository = SettingsRepository(userDefaults: userDefaults ?? .standard)
        var state = NotificationState()
        state.hasWarningBeenNotified = true
        state.hasCriticalBeenNotified = true
        state.lastPercentage = 85

        try await repository.saveNotificationState(state)
        let loaded = await repository.loadNotificationState()

        XCTAssertEqual(loaded, state)
    }
}
