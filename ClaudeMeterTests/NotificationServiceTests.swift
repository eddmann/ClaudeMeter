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
    private let accountId = UUID()
    private let otherAccountId = UUID()

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

        await service.evaluateThresholds(accountId: accountId, accountLabel: "TestAccount", usageData: usageData, settings: settings)

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

        await service.evaluateThresholds(accountId: accountId, accountLabel: "TestAccount", usageData: usageData, settings: settings)

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

        await service.evaluateThresholds(accountId: accountId, accountLabel: "TestAccount", usageData: usageData, settings: settings)

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

        await service.evaluateThresholds(accountId: accountId, accountLabel: "TestAccount", usageData: usageData, settings: settings)
        await service.evaluateThresholds(accountId: accountId, accountLabel: "TestAccount", usageData: usageData, settings: settings)

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

        await service.evaluateThresholds(accountId: accountId, accountLabel: "TestAccount", usageData: usageData, settings: settings)

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

        await service.evaluateThresholds(accountId: accountId, accountLabel: "TestAccount", usageData: makeUsageData(percentage: 80), settings: settings)
        await service.evaluateThresholds(accountId: accountId, accountLabel: "TestAccount", usageData: makeUsageData(percentage: 50), settings: settings)
        await service.evaluateThresholds(accountId: accountId, accountLabel: "TestAccount", usageData: makeUsageData(percentage: 80), settings: settings)

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
        state.lastSessionPercentageByAccount[accountId] = 100
        try? await settingsRepository.saveNotificationState(state)

        await service.evaluateThresholds(accountId: accountId, accountLabel: "TestAccount", usageData: makeUsageData(percentage: 0), settings: settings)

        XCTAssertEqual(notificationCenter.addedRequests.count, 1)
        XCTAssertEqual(notificationCenter.addedRequests.first?.content.categoryIdentifier, "usage.reset")
    }

    func test_resetNotificationFiresExactlyOncePerReset() async {
        // Repro for the multi-account reset spam bug: with per-account state, repeated
        // refreshes while utilization stays at 0 must NOT keep firing the reset notification.
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
        state.lastSessionPercentageByAccount[accountId] = 100
        try? await settingsRepository.saveNotificationState(state)

        // First refresh: usage drops to 0 → reset fires.
        await service.evaluateThresholds(accountId: accountId, accountLabel: "TestAccount", usageData: makeUsageData(percentage: 0), settings: settings)
        // Subsequent refreshes while usage stays at 0 → no more reset notifications.
        await service.evaluateThresholds(accountId: accountId, accountLabel: "TestAccount", usageData: makeUsageData(percentage: 0), settings: settings)
        await service.evaluateThresholds(accountId: accountId, accountLabel: "TestAccount", usageData: makeUsageData(percentage: 0), settings: settings)

        XCTAssertEqual(notificationCenter.addedRequests.count, 1)
    }

    func test_resetNotification_doesNotFireWhenUserWasNotAtCap() async {
        // The reset is only actionable when the user was actually out of credits (utilization
        // hit 100%). A reset from a lower value isn't a "now you can use Claude again" moment
        // — the user wasn't blocked — so no notification fires.
        let settingsRepository = SettingsRepositoryFake()
        let notificationCenter = NotificationCenterSpy()
        let service = NotificationService(
            settingsRepository: settingsRepository,
            notificationCenter: notificationCenter
        )

        var settings = AppSettings.default
        settings.hasNotificationsEnabled = true
        settings.notificationThresholds.isNotifiedOnReset = true

        // User was at 75% — well above zero, but never hit the cap.
        var state = NotificationState()
        state.lastSessionPercentageByAccount[accountId] = 75
        try? await settingsRepository.saveNotificationState(state)

        // Session window resets — utilization drops to 0.
        await service.evaluateThresholds(accountId: accountId, accountLabel: "TestAccount", usageData: makeUsageData(percentage: 0), settings: settings)

        let resetNotifs = notificationCenter.addedRequests.filter { $0.content.categoryIdentifier == "usage.reset" }
        XCTAssertEqual(resetNotifs.count, 0)
    }

    func test_oneAccountActive_doesNotTriggerResetSpamOnAnotherAccountAtZero() async {
        // Direct repro for the multi-account false-positive: with the old global lastPercentage,
        // every refresh of account B (which sits at 0) would re-detect a "reset" because
        // account A had just bumped lastPercentage back to a non-zero value.
        let settingsRepository = SettingsRepositoryFake()
        let notificationCenter = NotificationCenterSpy()
        let service = NotificationService(
            settingsRepository: settingsRepository,
            notificationCenter: notificationCenter
        )

        var settings = AppSettings.default
        settings.hasNotificationsEnabled = true
        settings.notificationThresholds.isNotifiedOnReset = true

        // Three rounds of: A at 50%, B at 0%. No reset notification should ever fire for B
        // (it never transitioned from > 0 to 0 — it's been at 0 the entire time).
        for _ in 0..<3 {
            await service.evaluateThresholds(accountId: accountId, accountLabel: "A", usageData: makeUsageData(percentage: 50), settings: settings)
            await service.evaluateThresholds(accountId: otherAccountId, accountLabel: "B", usageData: makeUsageData(percentage: 0), settings: settings)
        }

        let resetNotifs = notificationCenter.addedRequests.filter { $0.content.categoryIdentifier == "usage.reset" }
        XCTAssertEqual(resetNotifs.count, 0, "Account B was never above 0; no reset notif should fire for it")
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
