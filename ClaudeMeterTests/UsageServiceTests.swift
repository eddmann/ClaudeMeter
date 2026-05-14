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

        let service = UsageService(
            networkService: networkService,
            cacheRepository: cacheRepository,
            keychainRepository: keychainRepository
        )

        let account = ClaudeAccount(label: "Test")

        do {
            _ = try await service.fetchUsage(for: account, isPrimary: true, forceRefresh: false)
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

        let service = UsageService(
            networkService: networkService,
            cacheRepository: cacheRepository,
            keychainRepository: keychainRepository
        )

        let account = ClaudeAccount(label: "Test", organizationId: UUID(uuidString: TestConstants.organizationUUIDString))
        try await keychainRepository.save(sessionKey: TestConstants.sessionKeyValue, account: account.keychainAccount)
        await cacheRepository.seed(expectedUsage, accountId: account.id)

        let usageData = try await service.fetchUsage(for: account, isPrimary: true, forceRefresh: false)
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
        let networkService = NetworkServiceStub(responseData: responseData)
        let cacheRepository = CacheRepositoryFake()
        let keychainRepository = KeychainRepositoryFake()

        let service = UsageService(
            networkService: networkService,
            cacheRepository: cacheRepository,
            keychainRepository: keychainRepository
        )

        let account = ClaudeAccount(label: "Test", organizationId: UUID(uuidString: TestConstants.organizationUUIDString))
        try await keychainRepository.save(sessionKey: TestConstants.sessionKeyValue, account: account.keychainAccount)
        await cacheRepository.seed(cachedUsage, accountId: account.id)

        let usageData = try await service.fetchUsage(for: account, isPrimary: true, forceRefresh: true)
        let cached = await cacheRepository.get(accountId: account.id)
        let requestCount = await networkService.requestCount

        XCTAssertEqual(usageData.sessionUsage.utilization, TestConstants.sessionPercentage)
        XCTAssertEqual(usageData.weeklyUsage.utilization, TestConstants.weeklyPercentage)
        XCTAssertEqual(cached?.sessionUsage.utilization, TestConstants.sessionPercentage)
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

        let service = UsageService(
            networkService: networkService,
            cacheRepository: cacheRepository,
            keychainRepository: keychainRepository
        )

        let account = ClaudeAccount(label: "Test", organizationId: UUID(uuidString: TestConstants.organizationUUIDString))
        try await keychainRepository.save(sessionKey: TestConstants.sessionKeyValue, account: account.keychainAccount)

        _ = try await service.fetchUsage(for: account, isPrimary: true, forceRefresh: true)
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

        let service = UsageService(
            networkService: networkService,
            cacheRepository: cacheRepository,
            keychainRepository: keychainRepository
        )

        let account = ClaudeAccount(label: "Test", organizationId: UUID(uuidString: TestConstants.organizationUUIDString))
        try await keychainRepository.save(sessionKey: TestConstants.sessionKeyValue, account: account.keychainAccount)

        let usageData = try await service.fetchUsage(for: account, isPrimary: true, forceRefresh: true)

        XCTAssertEqual(usageData.sessionUsage.utilization, TestConstants.sessionPercentage)
        XCTAssertEqual(usageData.weeklyUsage.utilization, TestConstants.weeklyPercentage)
        assertDate(usageData.sessionUsage.resetAt, equalsIso8601String: TestConstants.sessionResetDateString)
        assertDate(usageData.weeklyUsage.resetAt, equalsIso8601String: TestConstants.weeklyResetDateString)
    }

    func test_usageFetch_withInvalidPayload_surfacesInvalidResponse() async throws {
        let responseData = try makeUsageResponseData(
            sessionUtilization: TestConstants.sessionPercentage,
            weeklyUtilization: TestConstants.weeklyPercentage,
            sessionResetAt: nil,
            weeklyResetAt: TestConstants.weeklyResetDateString,
            sonnetUtilization: nil,
            sonnetResetAt: nil
        )
        let networkService = NetworkServiceStub(responseData: responseData)
        let cacheRepository = CacheRepositoryFake()
        let keychainRepository = KeychainRepositoryFake()

        let service = UsageService(
            networkService: networkService,
            cacheRepository: cacheRepository,
            keychainRepository: keychainRepository
        )

        let account = ClaudeAccount(label: "Test", organizationId: UUID(uuidString: TestConstants.organizationUUIDString))
        try await keychainRepository.save(sessionKey: TestConstants.sessionKeyValue, account: account.keychainAccount)

        do {
            _ = try await service.fetchUsage(for: account, isPrimary: true, forceRefresh: true)
            XCTFail("Expected invalidResponse error")
        } catch AppError.networkError(let networkError) {
            if case .invalidResponse = networkError { return }
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

        let service = UsageService(
            networkService: networkService,
            cacheRepository: cacheRepository,
            keychainRepository: keychainRepository
        )

        let account = ClaudeAccount(label: "Test", organizationId: UUID(uuidString: TestConstants.organizationUUIDString))
        try await keychainRepository.save(sessionKey: TestConstants.sessionKeyValue, account: account.keychainAccount)

        let usageData = try await service.fetchUsage(for: account, isPrimary: true, forceRefresh: true)

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
        UsageLimitResponse(utilization: $0, resetsAt: sonnetResetAt)
    }

    let response = UsageAPIResponse(
        fiveHour: UsageLimitResponse(utilization: sessionUtilization, resetsAt: sessionResetAt),
        sevenDay: UsageLimitResponse(utilization: weeklyUtilization, resetsAt: weeklyResetAt),
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
