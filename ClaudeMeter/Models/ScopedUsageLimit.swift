//
//  ScopedUsageLimit.swift
//  ClaudeMeter
//

import Foundation

/// A weekly limit the API scopes to a model or surface. The API supplies `name`
/// itself, so a model released after this build still surfaces here.
struct ScopedUsageLimit: Codable, Equatable, Sendable, Identifiable {
    let name: String
    let limit: UsageLimit
    let isActive: Bool

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name
        case limit
        case isActive = "is_active"
    }
}

extension ScopedUsageLimit {
    var title: String {
        "Weekly \(name)"
    }
}
