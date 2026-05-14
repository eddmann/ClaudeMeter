//
//  UsageService.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-14.
//

import Foundation
import os

/// Actor-isolated usage service with retry logic
actor UsageService: UsageServiceProtocol {
    private static let logger = Logger(subsystem: "com.claudemeter", category: "UsageService")
    private let networkService: NetworkServiceProtocol
    private let cacheRepository: CacheRepositoryProtocol
    private let keychainRepository: KeychainRepositoryProtocol

    private let maxRetries = Constants.Network.maxRetries
    private let baseURL = "https://claude.ai/api"

    init(
        networkService: NetworkServiceProtocol,
        cacheRepository: CacheRepositoryProtocol,
        keychainRepository: KeychainRepositoryProtocol
    ) {
        self.networkService = networkService
        self.cacheRepository = cacheRepository
        self.keychainRepository = keychainRepository
    }

    /// Fetch usage data for an account with cache integration and exponential backoff retry.
    func fetchUsage(for account: ClaudeAccount, isPrimary: Bool, forceRefresh: Bool) async throws -> UsageData {
        let sessionKeyString: String
        do {
            sessionKeyString = try await keychainRepository.retrieve(account: account.keychainAccount)
        } catch KeychainError.notFound {
            throw AppError.noSessionKey
        } catch let error as KeychainError {
            throw AppError.keychainError(error)
        }

        let sessionKey = try SessionKey(sessionKeyString)

        if forceRefresh {
            await cacheRepository.invalidate(accountId: account.id)
        }

        if let cachedData = await cacheRepository.get(accountId: account.id) {
            return cachedData
        }

        let organizationId: UUID
        if let cached = account.organizationId {
            organizationId = cached
        } else if let embedded = sessionKey.organizationId {
            organizationId = embedded
        } else {
            let orgs = try await fetchOrganizations(sessionKey: sessionKey)
            guard let firstOrg = orgs.first,
                  let uuid = firstOrg.organizationUUID else {
                throw AppError.organizationNotFound
            }
            organizationId = uuid
        }

        var lastError: Error?

        for attempt in 0..<maxRetries {
            do {
                let response: UsageAPIResponse = try await networkService.request(
                    "\(baseURL)/organizations/\(organizationId)/usage",
                    method: .get,
                    sessionKey: sessionKey.value
                )

                let usageData = try response.toDomain()
                await cacheRepository.set(usageData, accountId: account.id, isPrimary: isPrimary)
                return usageData

            } catch NetworkError.networkUnavailable {
                Self.logger.warning("Network unavailable (attempt \(attempt + 1)/\(self.maxRetries))")
                lastError = NetworkError.networkUnavailable
                let delay = pow(Constants.Network.backoffBase, Double(attempt))
                try await Task.sleep(for: .seconds(delay))
            } catch NetworkError.rateLimitExceeded {
                Self.logger.warning("Rate limit exceeded (attempt \(attempt + 1)/\(self.maxRetries))")
                lastError = NetworkError.rateLimitExceeded
                let delay = pow(Constants.Network.rateLimitBackoffBase, Double(attempt))
                try await Task.sleep(for: .seconds(delay))
            } catch NetworkError.authenticationFailed {
                Self.logger.error("Authentication failed - session key invalid")
                throw AppError.sessionKeyInvalid
            } catch let error as URLError where error.code == .timedOut ||
                                               error.code == .cannotConnectToHost ||
                                               error.code == .networkConnectionLost ||
                                               error.code == .notConnectedToInternet {
                Self.logger.warning("URL error: \(error.localizedDescription) (attempt \(attempt + 1)/\(self.maxRetries))")
                lastError = error
                let delay = pow(Constants.Network.backoffBase, Double(attempt))
                try await Task.sleep(for: .seconds(delay))
            } catch {
                Self.logger.error("API request failed: \(error.localizedDescription)")
                throw AppError.networkError(error as? NetworkError ?? .invalidResponse)
            }
        }

        if let lastKnown = await cacheRepository.getLastKnown(accountId: account.id) {
            Self.logger.warning("All retries failed, using cached data")
            return lastKnown
        }

        Self.logger.error("All retries failed, no cached data available")
        throw AppError.networkError(lastError as? NetworkError ?? .networkUnavailable)
    }

    /// Fetch list of organizations with explicit session key (for setup before keychain save)
    func fetchOrganizations(sessionKey: SessionKey) async throws -> [Organization] {
        let organizations: OrganizationListResponse = try await networkService.request(
            "\(baseURL)/organizations",
            method: .get,
            sessionKey: sessionKey.value
        )

        return organizations
    }

    /// Validate session key with Claude API
    func validateSessionKey(_ sessionKey: SessionKey) async throws -> Bool {
        do {
            let _: OrganizationListResponse = try await networkService.request(
                "\(baseURL)/organizations",
                method: .get,
                sessionKey: sessionKey.value
            )
            return true
        } catch NetworkError.authenticationFailed {
            return false
        } catch {
            throw error
        }
    }
}
