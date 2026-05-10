//
//  UsageServiceTests.swift
//  ClaudeMeterTests
//
//  Created by Edd on 2026-01-09.
//

import XCTest
@testable import ClaudeMeter

final class UsageServiceTests: XCTestCase {
    func test_usageFetch_requiresSessionKey() async {
        let networkService = NetworkServiceStub(responseData: Data())
        let cacheRepository = CacheRepositoryFake()
        let keychainRepository = KeychainRepositoryFake()
        let settingsRepository = SettingsRepositoryFake()

        let service = UsageService(
            networkService: networkService,
            cacheRepository: cacheRepository,
            keychainRepository: keychainRepository,
            settingsRepository: settingsRepository
        )

        do {
            _ = try await service.fetchUsage(forceRefresh: false)
            XCTFail("Expected noSessionKey error")
        } catch AppError.noSessionKey {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_userWithCachedUsage_seesCachedValueWithoutNetworkCall() async throws {
        let expectedUsage = makeUsageData(percentage: TestConstants.sessionPercentage)
        let networkService = NetworkServiceStub(responseData: Data())
        let cacheRepository = CacheRepositoryFake()
        let keychainRepository = KeychainRepositoryFake()
        let settingsRepository = SettingsRepositoryFake()

        let service = UsageService(
            networkService: networkService,
            cacheRepository: cacheRepository,
            keychainRepository: keychainRepository,
            settingsRepository: settingsRepository
        )

        try await keychainRepository.save(
            sessionKey: TestConstants.sessionKeyValue,
            account: "default"
        )
        await cacheRepository.set(expectedUsage)

        let usageData = try await service.fetchUsage(forceRefresh: false)
        let requestCount = await networkService.requestCount
        let lastEndpoint = await networkService.lastEndpoint

        XCTAssertEqual(usageData, expectedUsage)
        XCTAssertEqual(requestCount, 0)
        XCTAssertNil(lastEndpoint)
    }

    func test_userForcesRefresh_bypassesCacheAndUpdatesCache() async throws {
        let cachedUsage = makeUsageData(percentage: TestConstants.cachedPercentage)
        let responseData = try makeUsageResponseData(
            sessionUtilization: TestConstants.sessionPercentage,
            weeklyUtilization: TestConstants.weeklyPercentage,
            sessionResetAt: TestConstants.sessionResetDateString,
            weeklyResetAt: TestConstants.weeklyResetDateString,
            sonnetUtilization: nil,
            sonnetResetAt: nil
        )
        let expectedSessionPercentage = TestConstants.sessionPercentage
        let expectedWeeklyPercentage = TestConstants.weeklyPercentage
        let networkService = NetworkServiceStub(responseData: responseData)
        let cacheRepository = CacheRepositoryFake()
        let keychainRepository = KeychainRepositoryFake()
        let settingsRepository = SettingsRepositoryFake()

        let service = UsageService(
            networkService: networkService,
            cacheRepository: cacheRepository,
            keychainRepository: keychainRepository,
            settingsRepository: settingsRepository
        )

        try await keychainRepository.save(
            sessionKey: TestConstants.sessionKeyValue,
            account: "default"
        )
        var settings = AppSettings.default
        settings.cachedOrganizationId = UUID(uuidString: TestConstants.organizationUUIDString)
        try await settingsRepository.save(settings)
        await cacheRepository.set(cachedUsage)

        let usageData = try await service.fetchUsage(forceRefresh: true)
        let cachedData = await cacheRepository.cachedData
        let requestCount = await networkService.requestCount

        XCTAssertEqual(usageData.sessionUsage.utilization, expectedSessionPercentage)
        XCTAssertEqual(usageData.weeklyUsage.utilization, expectedWeeklyPercentage)
        XCTAssertEqual(cachedData?.sessionUsage.utilization, expectedSessionPercentage)
        XCTAssertEqual(cachedData?.weeklyUsage.utilization, expectedWeeklyPercentage)
        XCTAssertEqual(requestCount, 1)
    }

    func test_userWithCachedOrganization_fetchesUsageFromCachedOrg() async throws {
        let responseData = try makeUsageResponseData(
            sessionUtilization: TestConstants.sessionPercentage,
            weeklyUtilization: TestConstants.weeklyPercentage,
            sessionResetAt: TestConstants.sessionResetDateString,
            weeklyResetAt: TestConstants.weeklyResetDateString,
            sonnetUtilization: nil,
            sonnetResetAt: nil
        )

        let networkService = NetworkServiceStub(responseData: responseData)
        let cacheRepository = CacheRepositoryFake()
        let keychainRepository = KeychainRepositoryFake()
        let settingsRepository = SettingsRepositoryFake()

        let service = UsageService(
            networkService: networkService,
            cacheRepository: cacheRepository,
            keychainRepository: keychainRepository,
            settingsRepository: settingsRepository
        )

        try await keychainRepository.save(
            sessionKey: TestConstants.sessionKeyValue,
            account: "default"
        )
        var settings = AppSettings.default
        settings.cachedOrganizationId = UUID(uuidString: TestConstants.organizationUUIDString)
        try await settingsRepository.save(settings)

        _ = try await service.fetchUsage(forceRefresh: true)
        let lastEndpoint = await networkService.lastEndpoint

        let expectedPath = "/organizations/\(TestConstants.organizationUUIDString)/usage"
        XCTAssertTrue(lastEndpoint?.contains(expectedPath) == true)
    }

    func test_usageFetch_showsUsageFromApiResponse() async throws {
        let responseData = try makeUsageResponseData(
            sessionUtilization: TestConstants.sessionPercentage,
            weeklyUtilization: TestConstants.weeklyPercentage,
            sessionResetAt: TestConstants.sessionResetDateString,
            weeklyResetAt: TestConstants.weeklyResetDateString,
            sonnetUtilization: nil,
            sonnetResetAt: nil
        )

        let networkService = NetworkServiceStub(responseData: responseData)
        let cacheRepository = CacheRepositoryFake()
        let keychainRepository = KeychainRepositoryFake()
        let settingsRepository = SettingsRepositoryFake()

        let service = UsageService(
            networkService: networkService,
            cacheRepository: cacheRepository,
            keychainRepository: keychainRepository,
            settingsRepository: settingsRepository
        )

        try await keychainRepository.save(
            sessionKey: TestConstants.sessionKeyValue,
            account: "default"
        )

        var settings = AppSettings.default
        settings.cachedOrganizationId = UUID(uuidString: TestConstants.organizationUUIDString)
        try await settingsRepository.save(settings)

        let usageData = try await service.fetchUsage(forceRefresh: true)

        XCTAssertEqual(usageData.sessionUsage.utilization, TestConstants.sessionPercentage)
        XCTAssertEqual(usageData.weeklyUsage.utilization, TestConstants.weeklyPercentage)
        assertDate(usageData.sessionUsage.resetAt, equalsIso8601String: TestConstants.sessionResetDateString)
        assertDate(usageData.weeklyUsage.resetAt, equalsIso8601String: TestConstants.weeklyResetDateString)
    }

    func test_usageFetch_withMissingResetAt_fillsInFallbackWindow() async throws {
        // The Claude API returns `resets_at: null` for windows with no usage in them yet
        // (typical for an account that hasn't been used today). The mapper should fall
        // back to "now + window duration" rather than refusing the response.
        let responseData = try makeUsageResponseData(
            sessionUtilization: 0,
            weeklyUtilization: TestConstants.weeklyPercentage,
            sessionResetAt: nil,
            weeklyResetAt: TestConstants.weeklyResetDateString,
            sonnetUtilization: nil,
            sonnetResetAt: nil
        )
        let networkService = NetworkServiceStub(responseData: responseData)
        let cacheRepository = CacheRepositoryFake()
        let keychainRepository = KeychainRepositoryFake()
        let settingsRepository = SettingsRepositoryFake()

        let service = UsageService(
            networkService: networkService,
            cacheRepository: cacheRepository,
            keychainRepository: keychainRepository,
            settingsRepository: settingsRepository
        )

        try await keychainRepository.save(
            sessionKey: TestConstants.sessionKeyValue,
            account: "default"
        )
        var settings = AppSettings.default
        settings.cachedOrganizationId = UUID(uuidString: TestConstants.organizationUUIDString)
        try await settingsRepository.save(settings)

        let usageData = try await service.fetchUsage(forceRefresh: true)

        XCTAssertEqual(usageData.sessionUsage.utilization, 0)
        // Reset date should be in the future, roughly one session window from now.
        XCTAssertGreaterThan(usageData.sessionUsage.resetAt.timeIntervalSinceNow, 0)
        XCTAssertLessThanOrEqual(
            usageData.sessionUsage.resetAt.timeIntervalSinceNow,
            Constants.Pacing.sessionWindow + 5
        )
    }

    func test_usageFetch_withMalformedResetAt_surfacesInvalidResponse() async throws {
        // A non-null but unparseable date string is still treated as a hard error.
        let responseData = try makeUsageResponseData(
            sessionUtilization: TestConstants.sessionPercentage,
            weeklyUtilization: TestConstants.weeklyPercentage,
            sessionResetAt: "not-a-date",
            weeklyResetAt: TestConstants.weeklyResetDateString,
            sonnetUtilization: nil,
            sonnetResetAt: nil
        )

        let networkService = NetworkServiceStub(responseData: responseData)
        let cacheRepository = CacheRepositoryFake()
        let keychainRepository = KeychainRepositoryFake()
        let settingsRepository = SettingsRepositoryFake()

        let service = UsageService(
            networkService: networkService,
            cacheRepository: cacheRepository,
            keychainRepository: keychainRepository,
            settingsRepository: settingsRepository
        )

        try await keychainRepository.save(
            sessionKey: TestConstants.sessionKeyValue,
            account: "default"
        )

        var settings = AppSettings.default
        settings.cachedOrganizationId = UUID(uuidString: TestConstants.organizationUUIDString)
        try await settingsRepository.save(settings)

        do {
            _ = try await service.fetchUsage(forceRefresh: true)
            XCTFail("Expected invalidResponse error")
        } catch AppError.networkError(let networkError) {
            if case .invalidResponse = networkError {
                return
            }
            XCTFail("Expected invalidResponse error")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_usageFetch_withSonnetUsage_showsSonnetUsage() async throws {
        let responseData = try makeUsageResponseData(
            sessionUtilization: TestConstants.sessionPercentage,
            weeklyUtilization: TestConstants.weeklyPercentage,
            sessionResetAt: TestConstants.sessionResetDateString,
            weeklyResetAt: TestConstants.weeklyResetDateString,
            sonnetUtilization: TestConstants.sonnetPercentage,
            sonnetResetAt: TestConstants.sonnetResetDateString
        )

        let networkService = NetworkServiceStub(responseData: responseData)
        let cacheRepository = CacheRepositoryFake()
        let keychainRepository = KeychainRepositoryFake()
        let settingsRepository = SettingsRepositoryFake()

        let service = UsageService(
            networkService: networkService,
            cacheRepository: cacheRepository,
            keychainRepository: keychainRepository,
            settingsRepository: settingsRepository
        )

        try await keychainRepository.save(
            sessionKey: TestConstants.sessionKeyValue,
            account: "default"
        )

        var settings = AppSettings.default
        settings.cachedOrganizationId = UUID(uuidString: TestConstants.organizationUUIDString)
        try await settingsRepository.save(settings)

        let usageData = try await service.fetchUsage(forceRefresh: true)

        XCTAssertEqual(usageData.sonnetUsage?.utilization, TestConstants.sonnetPercentage)
        if let resetAt = usageData.sonnetUsage?.resetAt {
            assertDate(resetAt, equalsIso8601String: TestConstants.sonnetResetDateString)
        } else {
            XCTFail("Expected sonnet usage reset date")
        }
    }
}

// MARK: - Helpers

private func makeUsageResponseData(
    sessionUtilization: Double,
    weeklyUtilization: Double,
    sessionResetAt: String?,
    weeklyResetAt: String?,
    sonnetUtilization: Double?,
    sonnetResetAt: String?
) throws -> Data {
    let sonnetUsage = sonnetUtilization.map {
        UsageLimitResponse(
            utilization: $0,
            resetsAt: sonnetResetAt
        )
    }

    let response = UsageAPIResponse(
        fiveHour: UsageLimitResponse(
            utilization: sessionUtilization,
            resetsAt: sessionResetAt
        ),
        sevenDay: UsageLimitResponse(
            utilization: weeklyUtilization,
            resetsAt: weeklyResetAt
        ),
        sevenDaySonnet: sonnetUsage
    )

    return try JSONEncoder().encode(response)
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

private func assertDate(_ date: Date, equalsIso8601String isoString: String) {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    guard let expectedDate = formatter.date(from: isoString) else {
        XCTFail("Invalid ISO8601 test date: \(isoString)")
        return
    }

    XCTAssertEqual(date.timeIntervalSince1970, expectedDate.timeIntervalSince1970, accuracy: 0.001)
}
