//
//  CacheRepositoryFake.swift
//  ClaudeMeterTests
//
//  Created by Edd on 2026-01-09.
//

import Foundation
@testable import ClaudeMeter

actor CacheRepositoryFake: CacheRepositoryProtocol {
    private(set) var cachedByAccount: [UUID: UsageData] = [:]
    private(set) var lastKnownByAccount: [UUID: UsageData] = [:]
    private(set) var primaryWrites: [UUID: Bool] = [:]

    /// Convenience accessor used by older tests that operate on a single implicit account.
    var cachedData: UsageData? { cachedByAccount.values.first }

    func get(accountId: UUID) async -> UsageData? {
        cachedByAccount[accountId]
    }

    func set(_ data: UsageData, accountId: UUID, isPrimary: Bool) async {
        cachedByAccount[accountId] = data
        lastKnownByAccount[accountId] = data
        primaryWrites[accountId] = isPrimary
    }

    func invalidate(accountId: UUID) async {
        cachedByAccount[accountId] = nil
    }

    func getLastKnown(accountId: UUID) async -> UsageData? {
        lastKnownByAccount[accountId]
    }

    func purge(accountId: UUID) async {
        cachedByAccount[accountId] = nil
        lastKnownByAccount[accountId] = nil
    }

    /// Test convenience: seed the cache for a specific account without going through `set`.
    func seed(_ data: UsageData, accountId: UUID) async {
        cachedByAccount[accountId] = data
        lastKnownByAccount[accountId] = data
    }
}
