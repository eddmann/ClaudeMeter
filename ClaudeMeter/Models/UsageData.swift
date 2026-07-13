//
//  UsageData.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-14.
//

import Foundation

/// Complete usage data across all limit types
struct UsageData: Codable, Equatable, Sendable {
    /// 5-hour rolling session usage
    let sessionUsage: UsageLimit

    /// 7-day weekly usage across all models
    let weeklyUsage: UsageLimit

    /// 7-day limits scoped to a specific model, in the order the API reported them
    let scopedUsage: [ScopedUsageLimit]

    /// Timestamp of when this data was fetched
    let lastUpdated: Date

    enum CodingKeys: String, CodingKey {
        case sessionUsage = "session_usage"
        case weeklyUsage = "weekly_usage"
        case scopedUsage = "scoped_usage"
        case lastUpdated = "last_updated"
    }

    /// Read-only: caches written before scoped limits existed carry a single Sonnet entry.
    /// Kept out of `CodingKeys` so `encode` stays synthesized.
    private enum LegacyCodingKeys: String, CodingKey {
        case sonnetUsage = "sonnet_usage"
    }
}

extension UsageData {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        sessionUsage = try container.decode(UsageLimit.self, forKey: .sessionUsage)
        weeklyUsage = try container.decode(UsageLimit.self, forKey: .weeklyUsage)
        lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)

        if let scoped = try container.decodeIfPresent([ScopedUsageLimit].self, forKey: .scopedUsage) {
            scopedUsage = scoped
        } else {
            let legacy = try decoder.container(keyedBy: LegacyCodingKeys.self)
            scopedUsage = try legacy.decodeIfPresent(UsageLimit.self, forKey: .sonnetUsage)
                .map { [ScopedUsageLimit(name: "Sonnet", limit: $0, isActive: false)] } ?? []
        }
    }
}

extension UsageData {
    /// Returns the primary usage level for menu bar display
    var primaryStatus: UsageStatus {
        sessionUsage.status
    }

    /// Human-readable staleness indicator
    var freshnessDescription: String {
        let elapsed = Date().timeIntervalSince(lastUpdated)
        if elapsed < 60 {
            return "just now"
        } else if elapsed < 3600 {
            return "\(Int(elapsed / 60)) minutes ago"
        } else {
            return "\(Int(elapsed / 3600)) hours ago"
        }
    }

    var isStale: Bool {
        Date().timeIntervalSince(lastUpdated) > Constants.Refresh.stalenessThreshold
    }
}
