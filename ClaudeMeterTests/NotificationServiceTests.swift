//
//  NotificationServiceTests.swift
//  ClaudeMeterTests
//
//  Created by Edd on 2026-01-09.
//

import XCTest
@testable import ClaudeMeter

@MainActor
final class NotificationServiceTests: XCTestCase {
    func test_userReceivesWarningNotificationWhenUsageCrossesThreshold() async {
        let settingsRepository = SettingsRepositoryFake()
        let notificationCenter = NotificationCenterSpy()
        let service = NotificationService(
            settingsRepository: settingsRepository,
            notificationCenter: notificationCenter
        )

        var settings = AppSettings.default
        settings.hasNotificationsEnabled = true
        settings.notificationThresholds.warningThreshold = 75
        settings.notificationThresholds.criticalThreshold = 90

        let usageData = makeUsageData(percentage: 80)

        await service.evaluateThresholds(accountLabel: "TestAccount", usageData: usageData, settings: settings)

        XCTAssertEqual(notificationCenter.addedRequests.count, 1)
        XCTAssertEqual(notificationCenter.addedRequests.first?.content.userInfo["threshold"] as? String, "warning")
    }

    func test_userWithNotificationsDisabled_doesNotReceiveThresholdNotification() async {
        let settingsRepository = SettingsRepositoryFake()
        let notificationCenter = NotificationCenterSpy()
        let service = NotificationService(
            settingsRepository: settingsRepository,
            notificationCenter: notificationCenter
        )

        var settings = AppSettings.default
        settings.hasNotificationsEnabled = false
        settings.notificationThresholds.warningThreshold = 75

        let usageData = makeUsageData(percentage: 80)

        await service.evaluateThresholds(accountLabel: "TestAccount", usageData: usageData, settings: settings)

        XCTAssertTrue(notificationCenter.addedRequests.isEmpty)
    }

    func test_userWithoutSystemPermission_doesNotReceiveNotification() async {
        let settingsRepository = SettingsRepositoryFake()
        let notificationCenter = NotificationCenterSpy()
        notificationCenter.authorizationStatus = .denied

        let service = NotificationService(
            settingsRepository: settingsRepository,
            notificationCenter: notificationCenter
        )

        var settings = AppSettings.default
        settings.hasNotificationsEnabled = true
        settings.notificationThresholds.warningThreshold = 75

        let usageData = makeUsageData(percentage: 80)

        await service.evaluateThresholds(accountLabel: "TestAccount", usageData: usageData, settings: settings)

        XCTAssertTrue(notificationCenter.addedRequests.isEmpty)
    }

    func test_userDoesNotReceiveDuplicateWarningWithoutDroppingBelowThreshold() async {
        let settingsRepository = SettingsRepositoryFake()
        let notificationCenter = NotificationCenterSpy()
        let service = NotificationService(
            settingsRepository: settingsRepository,
            notificationCenter: notificationCenter
        )

        var settings = AppSettings.default
        settings.hasNotificationsEnabled = true
        settings.notificationThresholds.warningThreshold = 75
        settings.notificationThresholds.criticalThreshold = 90

        let usageData = makeUsageData(percentage: 80)

        await service.evaluateThresholds(accountLabel: "TestAccount", usageData: usageData, settings: settings)
        await service.evaluateThresholds(accountLabel: "TestAccount", usageData: usageData, settings: settings)

        XCTAssertEqual(notificationCenter.addedRequests.count, 1)
    }

    func test_userCrossesCriticalThreshold_receivesCriticalNotification() async {
        let settingsRepository = SettingsRepositoryFake()
        let notificationCenter = NotificationCenterSpy()
        let service = NotificationService(
            settingsRepository: settingsRepository,
            notificationCenter: notificationCenter
        )

        var settings = AppSettings.default
        settings.hasNotificationsEnabled = true
        settings.notificationThresholds.warningThreshold = 75
        settings.notificationThresholds.criticalThreshold = 90

        let usageData = makeUsageData(percentage: 95)

        await service.evaluateThresholds(accountLabel: "TestAccount", usageData: usageData, settings: settings)

        let sentCritical = notificationCenter.addedRequests.contains { request in
            request.content.userInfo["threshold"] as? String == "critical"
        }
        XCTAssertTrue(sentCritical)
    }

    func test_userReceivesWarningAgainAfterDroppingBelowThreshold() async {
        let settingsRepository = SettingsRepositoryFake()
        let notificationCenter = NotificationCenterSpy()
        let service = NotificationService(
            settingsRepository: settingsRepository,
            notificationCenter: notificationCenter
        )

        var settings = AppSettings.default
        settings.hasNotificationsEnabled = true
        settings.notificationThresholds.warningThreshold = 75
        settings.notificationThresholds.criticalThreshold = 90

        await service.evaluateThresholds(accountLabel: "TestAccount", usageData: makeUsageData(percentage: 80), settings: settings)
        await service.evaluateThresholds(accountLabel: "TestAccount", usageData: makeUsageData(percentage: 50), settings: settings)
        await service.evaluateThresholds(accountLabel: "TestAccount", usageData: makeUsageData(percentage: 80), settings: settings)

        XCTAssertEqual(notificationCenter.addedRequests.count, 2)
    }

    func test_userReceivesResetNotificationWhenUsageResets() async {
        let settingsRepository = SettingsRepositoryFake()
        let notificationCenter = NotificationCenterSpy()
        let service = NotificationService(
            settingsRepository: settingsRepository,
            notificationCenter: notificationCenter
        )

        var settings = AppSettings.default
        settings.hasNotificationsEnabled = true
        settings.notificationThresholds.isNotifiedOnReset = true

        var state = NotificationState()
        state.lastPercentage = 50
        try? await settingsRepository.saveNotificationState(state)

        await service.evaluateThresholds(accountLabel: "TestAccount", usageData: makeUsageData(percentage: 0), settings: settings)

        XCTAssertEqual(notificationCenter.addedRequests.count, 1)
        XCTAssertEqual(notificationCenter.addedRequests.first?.content.categoryIdentifier, "usage.reset")
    }
}

// MARK: - Helpers

@MainActor
private func makeUsageData(percentage: Double) -> UsageData {
    let resetDate = Date().addingTimeInterval(TestConstants.oneHourInterval)
    let sessionUsage = UsageLimit(utilization: percentage, resetAt: resetDate)
    let weeklyUsage = UsageLimit(utilization: TestConstants.weeklyPercentage, resetAt: resetDate)

    return UsageData(
        sessionUsage: sessionUsage,
        weeklyUsage: weeklyUsage,
        sonnetUsage: nil,
        lastUpdated: Date()
    )
}
