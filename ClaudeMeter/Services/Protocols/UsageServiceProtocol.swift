//
//  UsageServiceProtocol.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-14.
//

import Foundation

/// Protocol for Claude.ai usage operations
protocol UsageServiceProtocol: Actor {
    /// Fetch usage data for the user's organization
    /// - Parameter forceRefresh: If true, clears cache before fetching new data
    func fetchUsage(forceRefresh: Bool) async throws -> UsageData

    /// Fetch list of organizations for the user (from keychain)
    func fetchOrganizations() async throws -> [Organization]

    /// Fetch list of organizations with explicit session key (for setup)
    func fetchOrganizations(sessionKey: SessionKey) async throws -> [Organization]

    /// Validate session key with Claude API
    func validateSessionKey(_ sessionKey: SessionKey) async throws -> Bool
}
