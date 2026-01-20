//
//  Organization.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-14.
//

import Foundation

/// Claude organization account
struct Organization: Codable, Equatable, Sendable {
    /// Integer ID
    let id: Int

    /// UUID identifier
    let uuid: String

    /// Organization display name
    let name: String

    /// Organization capabilities (e.g., "api", "chat", "claude_max")
    let capabilities: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case uuid
        case name
        case capabilities
    }

    /// Convert uuid string to UUID
    var organizationUUID: UUID? {
        UUID(uuidString: uuid)
    }

    /// Check if this organization has Claude.ai chat capability
    var hasChatCapability: Bool {
        capabilities?.contains("chat") ?? false
    }
}
