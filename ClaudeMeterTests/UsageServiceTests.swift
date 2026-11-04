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

        XCTAssertEqual(usageData.sessionUsage?.utilization, expectedSessionPercentage)
        XCTAssertEqual(usageData.weeklyUsage.utilization, expectedWeeklyPercentage)
        XCTAssertEqual(cachedData?.sessionUsage?.utilization, expectedSessionPercentage)
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

        XCTAssertEqual(usageData.sessionUsage?.utilization, TestConstants.sessionPercentage)
        XCTAssertEqual(usageData.weeklyUsage.utilization, TestConstants.weeklyPercentage)
        assertDate(try XCTUnwrap(usageData.sessionUsage).resetAt, equalsIso8601String: TestConstants.sessionResetDateString)
        assertDate(usageData.weeklyUsage.resetAt, equalsIso8601String: TestConstants.weeklyResetDateString)
    }

    func test_usageFetch_withMissingResetAt_usesFallbackWindow() async throws {
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

        XCTAssertEqual(usageData.sessionUsage?.utilization, 0)
        let sessionUsage = try XCTUnwrap(usageData.sessionUsage)
        XCTAssertGreaterThan(sessionUsage.resetAt.timeIntervalSinceNow, 0)
        XCTAssertLessThanOrEqual(
            sessionUsage.resetAt.timeIntervalSinceNow,
            Constants.Pacing.sessionWindow + 5
        )
    }

    func test_usageFetch_withMalformedResetAt_surfacesInvalidResponse() async throws {
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

    func test_usageFetch_withoutFiveHourLimit_showsWeeklyUsageOnly() async throws {
        // Trimmed from a real claude.ai response for a Max account with no 5-hour limit
        let responseData = Data("""
        {
          "five_hour": null,
          "seven_day": {
            "utilization": 4.0,
            "resets_at": "2026-11-05T01:00:00.343133+00:00",
            "limit_dollars": null,
            "used_dollars": null,
            "remaining_dollars": null,
            "locked_reason": null
          },
          "seven_day_sonnet": null,
          "seven_day_opus": null,
          "limits": [
            {
              "kind": "weekly_all",
              "group": "weekly",
              "percent": 4,
              "severity": "normal",
              "resets_at": "2026-11-05T01:00:00.343133+00:00",
              "scope": null,
              "is_active": true
            }
          ]
        }
        """.utf8)

        let usageData = try await fetchUsage(responseData: responseData)

        XCTAssertNil(usageData.sessionUsage)
        XCTAssertEqual(usageData.weeklyUsage.utilization, 4)
        assertDate(usageData.weeklyUsage.resetAt, equalsIso8601String: "2026-11-05T01:00:00.343Z")
        XCTAssertEqual(usageData.primaryUsage, usageData.weeklyUsage)
        XCTAssertEqual(usageData.primaryLimitName, "weekly limit")
    }

    func test_usageFetch_withResetAtWithoutFractionalSeconds_parsesDate() async throws {
        let responseData = try makeUsageResponseData(
            sessionUtilization: TestConstants.sessionPercentage,
            weeklyUtilization: TestConstants.weeklyPercentage,
            sessionResetAt: "2026-11-04T20:00:00+00:00",
            weeklyResetAt: "2026-11-05T01:00:00+00:00",
            sonnetUtilization: nil,
            sonnetResetAt: nil
        )

        let usageData = try await fetchUsage(responseData: responseData)

        assertDate(try XCTUnwrap(usageData.sessionUsage).resetAt, equalsIso8601String: "2026-11-04T20:00:00.000Z")
        assertDate(usageData.weeklyUsage.resetAt, equalsIso8601String: "2026-11-05T01:00:00.000Z")
        XCTAssertEqual(usageData.primaryLimitName, "5-hour session")
    }
}

// MARK: - Helpers

private func fetchUsage(responseData: Data) async throws -> UsageData {
    let keychainRepository = KeychainRepositoryFake()
    let settingsRepository = SettingsRepositoryFake()
    let service = UsageService(
        networkService: NetworkServiceStub(responseData: responseData),
        cacheRepository: CacheRepositoryFake(),
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

    return try await service.fetchUsage(forceRefresh: true)
}

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
