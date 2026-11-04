//
//  UsageData.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-14.
//

import Foundation

/// Complete usage data across all limit types
struct UsageData: Codable, Equatable, Sendable {
    /// 5-hour rolling session usage (nil when the account has no 5-hour limit)
    let sessionUsage: UsageLimit?

    /// 7-day weekly usage across all models
    let weeklyUsage: UsageLimit

    /// 7-day Sonnet-specific usage (nil if not used)
    let sonnetUsage: UsageLimit?

    /// Timestamp of when this data was fetched
    let lastUpdated: Date

    enum CodingKeys: String, CodingKey {
        case sessionUsage = "session_usage"
        case weeklyUsage = "weekly_usage"
        case sonnetUsage = "sonnet_usage"
        case lastUpdated = "last_updated"
    }
}

extension UsageData {
    /// The limit shown in the menu bar and used for notifications:
    /// the 5-hour session when present, otherwise the weekly limit
    var primaryUsage: UsageLimit {
        sessionUsage ?? weeklyUsage
    }

    /// Human-readable name of `primaryUsage`, used in notification text
    var primaryLimitName: String {
        sessionUsage == nil ? Self.weeklyLimitName : Self.sessionLimitName
    }

    static let sessionLimitName = "5-hour session"
    static let weeklyLimitName = "weekly limit"

    /// Returns the primary usage level for menu bar display
    var primaryStatus: UsageStatus {
        primaryUsage.status
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
