//
//  UsageServiceProtocol.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-14.
//

import Foundation

/// Protocol for Claude.ai usage operations
protocol UsageServiceProtocol: Actor {
    /// Fetch usage data for a specific account.
    /// - Parameters:
    ///   - account: the account to fetch usage for
    ///   - isPrimary: when true, the public `~/.claudemeter/usage.json` export is updated
    ///   - forceRefresh: if true, bypasses the cache before fetching
    func fetchUsage(for account: ClaudeAccount, isPrimary: Bool, forceRefresh: Bool) async throws -> UsageData

    /// Fetch list of organizations with explicit session key (for setup before keychain save)
    func fetchOrganizations(sessionKey: SessionKey) async throws -> [Organization]

    /// Validate session key with Claude API
    func validateSessionKey(_ sessionKey: SessionKey) async throws -> Bool
}
