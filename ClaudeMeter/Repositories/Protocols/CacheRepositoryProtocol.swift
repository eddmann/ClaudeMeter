//
//  CacheRepositoryProtocol.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-14.
//

import Foundation

/// Protocol for two-tier usage data caching, scoped per account.
protocol CacheRepositoryProtocol: Actor {
    /// Get cached usage data for an account (respects TTL).
    func get(accountId: UUID) async -> UsageData?

    /// Cache usage data for an account.
    /// - Parameter isPrimary: when true, also writes the public `~/.claudemeter/usage.json` export
    ///   (preserves backwards compatibility with statusline scripts that expected a single account).
    func set(_ data: UsageData, accountId: UUID, isPrimary: Bool) async

    /// Invalidate the in-memory cache for an account.
    func invalidate(accountId: UUID) async

    /// Get last known data from disk for an account (ignores TTL) for offline display.
    func getLastKnown(accountId: UUID) async -> UsageData?

    /// Drop all on-disk cache files (e.g. when an account is removed or all accounts are cleared).
    func purge(accountId: UUID) async
}
