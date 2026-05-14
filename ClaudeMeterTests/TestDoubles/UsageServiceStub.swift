//
//  UsageServiceStub.swift
//  ClaudeMeterTests
//
//  Created by Edd on 2026-01-09.
//

import Foundation
@testable import ClaudeMeter

actor UsageServiceStub: UsageServiceProtocol {
    let fetchUsageResult: Result<UsageData, Error>
    let isSessionKeyValid: Bool
    let organizations: [Organization]

    private(set) var lastFetchedAccountId: UUID?
    private(set) var lastFetchWasPrimary: Bool?

    init(
        fetchUsageResult: Result<UsageData, Error>,
        organizations: [Organization] = [],
        isSessionKeyValid: Bool = true
    ) {
        self.fetchUsageResult = fetchUsageResult
        self.organizations = organizations
        self.isSessionKeyValid = isSessionKeyValid
    }

    func fetchUsage(for account: ClaudeAccount, isPrimary: Bool, forceRefresh: Bool) async throws -> UsageData {
        lastFetchedAccountId = account.id
        lastFetchWasPrimary = isPrimary
        switch fetchUsageResult {
        case .success(let data):
            return data
        case .failure(let error):
            throw error
        }
    }

    func fetchOrganizations(sessionKey: SessionKey) async throws -> [Organization] {
        organizations
    }

    func validateSessionKey(_ sessionKey: SessionKey) async throws -> Bool {
        isSessionKeyValid
    }
}
