//
//  KeychainRepositoryFake.swift
//  ClaudeMeterTests
//
//  Created by Edd on 2026-01-09.
//

import Foundation
@testable import ClaudeMeter

actor KeychainRepositoryFake: KeychainRepositoryProtocol {
    private(set) var keysByAccount: [String: String] = [:]

    func save(sessionKey: String, account: String) async throws {
        keysByAccount[account] = sessionKey
    }

    func retrieve(account: String) async throws -> String {
        guard let key = keysByAccount[account] else {
            throw KeychainError.notFound
        }
        return key
    }

    func update(sessionKey: String, account: String) async throws {
        keysByAccount[account] = sessionKey
    }

    func delete(account: String) async throws {
        keysByAccount[account] = nil
    }

    func exists(account: String) async -> Bool {
        keysByAccount[account] != nil
    }
}
