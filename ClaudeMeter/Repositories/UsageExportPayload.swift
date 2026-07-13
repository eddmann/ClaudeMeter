//
//  UsageExportPayload.swift
//  ClaudeMeter
//

import Foundation

/// The public `~/.claudemeter/usage.json` contract. Separate from `UsageData` so the
/// domain model and disk cache can change shape without breaking external scripts.
struct UsageExportPayload: Encodable {
    let sessionUsage: UsageLimit
    let weeklyUsage: UsageLimit
    let scopedUsage: [ScopedUsageLimit]

    /// Deprecated alias for `scopedUsage`, kept so existing statusline scripts keep working.
    let sonnetUsage: UsageLimit?

    let lastUpdated: Date

    init(_ data: UsageData) {
        sessionUsage = data.sessionUsage
        weeklyUsage = data.weeklyUsage
        scopedUsage = data.scopedUsage
        sonnetUsage = data.scopedUsage
            .first { $0.name.caseInsensitiveCompare("Sonnet") == .orderedSame }?
            .limit
        lastUpdated = data.lastUpdated
    }

    enum CodingKeys: String, CodingKey {
        case sessionUsage = "session_usage"
        case weeklyUsage = "weekly_usage"
        case scopedUsage = "scoped_usage"
        case sonnetUsage = "sonnet_usage"
        case lastUpdated = "last_updated"
    }
}
