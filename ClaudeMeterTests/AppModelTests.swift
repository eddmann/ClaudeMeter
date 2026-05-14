//
//  AppModelTests.swift
//  ClaudeMeterTests
//
//  Created by Edd on 2026-01-09.
//

import XCTest
@testable import ClaudeMeter

@MainActor
final class AppModelTests: XCTestCase {
    func test_bootstrap_withoutAnyAccount_showsSetupState() async {
        let appModel = makeAppModel(
            usageService: UsageServiceStub(fetchUsageResult: .failure(TestError(message: TestConstants.unexpectedErrorMessage)))
        )

        await appModel.bootstrap()

        XCTAssertTrue(appModel.isReady)
        XCTAssertFalse(appModel.isSetupComplete)
        XCTAssertTrue(appModel.settings.accounts.isEmpty)
    }

    func test_bootstrap_withConfiguredAccount_loadsUsage() async throws {
        let expectedUsage = makeUsageData(percentage: TestConstants.sessionPercentage)
        let usageService = UsageServiceStub(fetchUsageResult: .success(expectedUsage))
        let notificationService = NotificationServiceSpy()
        let settingsRepository = SettingsRepositoryFake()
        let keychainRepository = KeychainRepositoryFake()

        let account = ClaudeAccount(label: "Personal", organizationId: UUID(uuidString: TestConstants.organizationUUIDString))
        var seeded = AppSettings.default
        seeded.accounts = [account]
        try await settingsRepository.save(seeded)
        try await keychainRepository.save(sessionKey: TestConstants.sessionKeyValue, account: account.keychainAccount)

        let appModel = AppModel(
            settingsRepository: settingsRepository,
            keychainRepository: keychainRepository,
            usageService: usageService,
            notificationService: notificationService
        )

        await appModel.bootstrap()

        XCTAssertTrue(appModel.isReady)
        XCTAssertTrue(appModel.isSetupComplete)
        XCTAssertEqual(appModel.state(for: account.id).usageData, expectedUsage)
        XCTAssertNil(appModel.state(for: account.id).errorMessage)
        XCTAssertEqual(notificationService.lastEvaluatedUsageData, expectedUsage)
    }

    func test_bootstrap_withConfiguredAccount_surfacesFetchFailure() async throws {
        let failure = TestError(message: TestConstants.fetchFailureMessage)
        let usageService = UsageServiceStub(fetchUsageResult: .failure(failure))
        let notificationService = NotificationServiceSpy()
        let settingsRepository = SettingsRepositoryFake()
        let keychainRepository = KeychainRepositoryFake()

        let account = ClaudeAccount(label: "Personal", organizationId: UUID(uuidString: TestConstants.organizationUUIDString))
        var seeded = AppSettings.default
        seeded.accounts = [account]
        try await settingsRepository.save(seeded)
        try await keychainRepository.save(sessionKey: TestConstants.sessionKeyValue, account: account.keychainAccount)

        let appModel = AppModel(
            settingsRepository: settingsRepository,
            keychainRepository: keychainRepository,
            usageService: usageService,
            notificationService: notificationService
        )

        await appModel.bootstrap()

        XCTAssertTrue(appModel.isReady)
        XCTAssertTrue(appModel.isSetupComplete)
        XCTAssertNil(appModel.state(for: account.id).usageData)
        XCTAssertEqual(appModel.state(for: account.id).errorMessage, failure.localizedDescription)
        XCTAssertNil(notificationService.lastEvaluatedUsageData)
    }

    func test_addAccount_withInvalidSessionKey_returnsNil() async throws {
        let appModel = makeAppModel(
            usageService: UsageServiceStub(
                fetchUsageResult: .failure(TestError(message: TestConstants.unexpectedErrorMessage)),
                isSessionKeyValid: false
            )
        )
        appModel.isReady = true

        let result = try await appModel.addAccount(label: "Personal", sessionKey: TestConstants.sessionKeyValue)

        XCTAssertNil(result)
        XCTAssertTrue(appModel.settings.accounts.isEmpty)
    }

    func test_addAccount_withValidSessionKey_addsAndLoadsUsage() async throws {
        let expectedUsage = makeUsageData(percentage: TestConstants.sessionPercentage)
        let organization = Organization(
            id: 1,
            uuid: TestConstants.organizationUUIDString,
            name: "Test Org"
        )
        let usageService = UsageServiceStub(
            fetchUsageResult: .success(expectedUsage),
            organizations: [organization],
            isSessionKeyValid: true
        )
        let appModel = makeAppModel(usageService: usageService)
        appModel.isReady = true

        let account = try await appModel.addAccount(label: "Personal", sessionKey: TestConstants.sessionKeyValue)

        XCTAssertNotNil(account)
        XCTAssertEqual(appModel.settings.accounts.count, 1)
        XCTAssertEqual(appModel.settings.accounts.first?.label, "Personal")
        XCTAssertEqual(appModel.settings.accounts.first?.organizationId, UUID(uuidString: TestConstants.organizationUUIDString))
        XCTAssertEqual(appModel.state(for: account!.id).usageData, expectedUsage)
        XCTAssertFalse(appModel.settings.isFirstLaunch)
        XCTAssertTrue(appModel.isSetupComplete)
    }

    func test_addAccount_withoutOrganization_throws() async {
        let usageService = UsageServiceStub(
            fetchUsageResult: .failure(TestError(message: TestConstants.unexpectedErrorMessage)),
            organizations: [],
            isSessionKeyValid: true
        )
        let appModel = makeAppModel(usageService: usageService)
        appModel.isReady = true

        do {
            _ = try await appModel.addAccount(label: "Personal", sessionKey: TestConstants.sessionKeyValue)
            XCTFail("Expected organizationNotFound to be thrown")
        } catch AppError.organizationNotFound {
            XCTAssertTrue(appModel.settings.accounts.isEmpty)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_removeAccount_clearsKeychainAndState() async throws {
        let expectedUsage = makeUsageData(percentage: TestConstants.cachedPercentage)
        let usageService = UsageServiceStub(fetchUsageResult: .success(expectedUsage))
        let settingsRepository = SettingsRepositoryFake()
        let keychainRepository = KeychainRepositoryFake()

        let account = ClaudeAccount(label: "Personal", organizationId: UUID(uuidString: TestConstants.organizationUUIDString))
        var seeded = AppSettings.default
        seeded.accounts = [account]
        try await settingsRepository.save(seeded)
        try await keychainRepository.save(sessionKey: TestConstants.sessionKeyValue, account: account.keychainAccount)

        let appModel = AppModel(
            settingsRepository: settingsRepository,
            keychainRepository: keychainRepository,
            usageService: usageService,
            notificationService: NotificationServiceSpy()
        )
        await appModel.bootstrap()

        try await appModel.removeAccount(account.id)

        XCTAssertTrue(appModel.settings.accounts.isEmpty)
        XCTAssertFalse(appModel.isSetupComplete)
        XCTAssertNil(appModel.accountStates[account.id])
        let stillExists = await keychainRepository.exists(account: account.keychainAccount)
        XCTAssertFalse(stillExists)
    }

    func test_renameAccount_updatesLabel() {
        let appModel = makeAppModel(
            usageService: UsageServiceStub(fetchUsageResult: .failure(TestError(message: TestConstants.unexpectedErrorMessage)))
        )
        appModel.isReady = true
        let account = ClaudeAccount(label: "Original")
        appModel.settings.accounts = [account]

        appModel.renameAccount(account.id, label: "Renamed")

        XCTAssertEqual(appModel.settings.accounts.first?.label, "Renamed")
    }

    func test_legacyKeychainMigration_movesDefaultKeyToFirstAccount() async throws {
        let usageService = UsageServiceStub(fetchUsageResult: .failure(TestError(message: TestConstants.unexpectedErrorMessage)))
        let settingsRepository = SettingsRepositoryFake()
        let keychainRepository = KeychainRepositoryFake()

        // Simulate legacy state: account synthesised by AppSettings migration, key in legacy "default" slot.
        let migratedAccount = ClaudeAccount(label: "Default", organizationId: UUID(uuidString: TestConstants.organizationUUIDString))
        var seeded = AppSettings.default
        seeded.accounts = [migratedAccount]
        try await settingsRepository.save(seeded)
        try await keychainRepository.save(sessionKey: TestConstants.sessionKeyValue, account: "default")

        let appModel = AppModel(
            settingsRepository: settingsRepository,
            keychainRepository: keychainRepository,
            usageService: usageService,
            notificationService: NotificationServiceSpy()
        )
        await appModel.bootstrap()

        let legacyExists = await keychainRepository.exists(account: "default")
        let newExists = await keychainRepository.exists(account: migratedAccount.keychainAccount)
        XCTAssertFalse(legacyExists)
        XCTAssertTrue(newExists)
    }

    func test_userWithNotificationPermission_doesNotSeePermissionPrompt() async {
        let notificationService = NotificationServiceSpy()
        notificationService.hasPermission = true
        let appModel = makeAppModel(
            usageService: UsageServiceStub(fetchUsageResult: .failure(TestError(message: TestConstants.unexpectedErrorMessage))),
            notificationService: notificationService
        )

        await appModel.requestNotificationPermissionIfNeeded()

        XCTAssertEqual(notificationService.requestAuthorizationCallCount, 0)
    }

    func test_userWithoutNotificationPermission_isPromptedForPermission() async {
        let notificationService = NotificationServiceSpy()
        notificationService.hasPermission = false
        let appModel = makeAppModel(
            usageService: UsageServiceStub(fetchUsageResult: .failure(TestError(message: TestConstants.unexpectedErrorMessage))),
            notificationService: notificationService
        )

        await appModel.requestNotificationPermissionIfNeeded()

        XCTAssertEqual(notificationService.requestAuthorizationCallCount, 1)
    }

    func test_userSendsTestNotification_triggersNotificationService() async throws {
        let notificationService = NotificationServiceSpy()
        let appModel = makeAppModel(
            usageService: UsageServiceStub(fetchUsageResult: .failure(TestError(message: TestConstants.unexpectedErrorMessage))),
            notificationService: notificationService
        )

        try await appModel.sendTestNotification()

        XCTAssertEqual(notificationService.sentThresholdType, .warning)
        XCTAssertEqual(notificationService.sentThresholdPercentage, 85.0)
    }
}

// MARK: - Helpers

@MainActor
private func makeAppModel(
    usageService: UsageServiceProtocol,
    notificationService: NotificationServiceSpy? = nil,
    settingsRepository: SettingsRepositoryFake? = nil,
    keychainRepository: KeychainRepositoryFake? = nil
) -> AppModel {
    // Defaults are constructed inside the body because Swift 6 disallows main-actor-isolated
    // initialisers in nonisolated default-value expressions.
    AppModel(
        settingsRepository: settingsRepository ?? SettingsRepositoryFake(),
        keychainRepository: keychainRepository ?? KeychainRepositoryFake(),
        usageService: usageService,
        notificationService: notificationService ?? NotificationServiceSpy()
    )
}

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
