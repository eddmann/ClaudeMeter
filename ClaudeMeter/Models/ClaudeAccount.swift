//
//  ClaudeAccount.swift
//  ClaudeMeter
//

import Foundation

/// A single Claude.ai account being monitored.
/// Each account has its own session key (in Keychain) and its own menu bar status item.
struct ClaudeAccount: Codable, Equatable, Identifiable, Sendable, Hashable {
    /// Stable identifier used as the Keychain account name and cache key.
    let id: UUID

    /// User-facing label shown in settings and the menu bar (e.g. "Perso", "Client X").
    var label: String

    /// Cached organization UUID for this account (avoids round-trip on each refresh).
    var organizationId: UUID?

    init(id: UUID = UUID(), label: String, organizationId: UUID? = nil) {
        self.id = id
        self.label = label
        self.organizationId = organizationId
    }

    /// Keychain `account` parameter: scoped per-account so multiple session keys can coexist.
    var keychainAccount: String { id.uuidString }

    /// Single-character glyph used as a prefix in the menu bar to disambiguate accounts.
    var menuBarInitial: String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "?" }
        return String(first).uppercased()
    }

    enum CodingKeys: String, CodingKey {
        case id
        case label
        case organizationId = "organization_id"
    }
}
