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

        await service.evaluateThresholds(usageData: usageData, settings: settings)

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

        await service.evaluateThresholds(usageData: usageData, settings: settings)

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

        await service.evaluateThresholds(usageData: usageData, settings: settings)

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

        await service.evaluateThresholds(usageData: usageData, settings: settings)
        await service.evaluateThresholds(usageData: usageData, settings: settings)

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

        await service.evaluateThresholds(usageData: usageData, settings: settings)

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

        await service.evaluateThresholds(usageData: makeUsageData(percentage: 80), settings: settings)
        await service.evaluateThresholds(usageData: makeUsageData(percentage: 50), settings: settings)
        await service.evaluateThresholds(usageData: makeUsageData(percentage: 80), settings: settings)

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

        await service.evaluateThresholds(usageData: makeUsageData(percentage: 0), settings: settings)

        XCTAssertEqual(notificationCenter.addedRequests.count, 1)
        XCTAssertEqual(notificationCenter.addedRequests.first?.content.categoryIdentifier, "usage.reset")
    }

    func test_userWithoutFiveHourLimit_receivesWeeklyWarningNotification() async {
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

        let resetDate = Date().addingTimeInterval(TestConstants.oneHourInterval)
        let usageData = UsageData(
            sessionUsage: nil,
            weeklyUsage: UsageLimit(utilization: 80, resetAt: resetDate),
            sonnetUsage: nil,
            lastUpdated: Date()
        )

        await service.evaluateThresholds(usageData: usageData, settings: settings)

        XCTAssertEqual(notificationCenter.addedRequests.count, 1)
        let content = notificationCenter.addedRequests.first?.content
        XCTAssertEqual(content?.userInfo["threshold"] as? String, "warning")
        XCTAssertTrue(content?.body.contains("80% of your weekly limit") == true)
    }

    func test_whenFiveHourLimitDisappears_staleSessionWarningDoesNotSuppressWeeklyWarning() async throws {
        let settingsRepository = SettingsRepositoryFake()
        let notificationCenter = NotificationCenterSpy()
        let service = NotificationService(
            settingsRepository: settingsRepository,
            notificationCenter: notificationCenter
        )
        // State saved by an older version while tracking the 5-hour session
        try await settingsRepository.saveNotificationState(
            NotificationState(hasWarningBeenNotified: true, hasCriticalBeenNotified: false, lastPercentage: 80)
        )

        var settings = AppSettings.default
        settings.hasNotificationsEnabled = true
        settings.notificationThresholds.warningThreshold = 75
        settings.notificationThresholds.criticalThreshold = 90

        await service.evaluateThresholds(usageData: makeWeeklyOnlyUsageData(percentage: 85), settings: settings)

        XCTAssertEqual(notificationCenter.addedRequests.count, 1)
        XCTAssertEqual(notificationCenter.addedRequests.first?.content.userInfo["threshold"] as? String, "warning")
        let state = await settingsRepository.loadNotificationState()
        XCTAssertEqual(state.trackedLimit, UsageData.weeklyLimitName)
    }

    func test_whenFiveHourLimitDisappears_doesNotSendFalseResetNotification() async throws {
        let settingsRepository = SettingsRepositoryFake()
        let notificationCenter = NotificationCenterSpy()
        let service = NotificationService(
            settingsRepository: settingsRepository,
            notificationCenter: notificationCenter
        )
        try await settingsRepository.saveNotificationState(
            NotificationState(lastPercentage: 30, trackedLimit: UsageData.sessionLimitName)
        )

        var settings = AppSettings.default
        settings.hasNotificationsEnabled = true
        settings.notificationThresholds.isNotifiedOnReset = true

        await service.evaluateThresholds(usageData: makeWeeklyOnlyUsageData(percentage: 0), settings: settings)

        XCTAssertTrue(notificationCenter.addedRequests.isEmpty)
    }
}

// MARK: - Helpers

@MainActor
private func makeWeeklyOnlyUsageData(percentage: Double) -> UsageData {
    UsageData(
        sessionUsage: nil,
        weeklyUsage: UsageLimit(
            utilization: percentage,
            resetAt: Date().addingTimeInterval(TestConstants.oneHourInterval)
        ),
        sonnetUsage: nil,
        lastUpdated: Date()
    )
}

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
