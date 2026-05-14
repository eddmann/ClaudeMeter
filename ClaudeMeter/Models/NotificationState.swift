//
//  NotificationState.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-14.
//

import Foundation

/// Tracks notification state per Claude account. Earlier versions kept these as global flags,
/// which produced spurious notifications in a multi-account setup: account A bumping
/// `lastPercentage` up to 50 would then make account B (still at 0) repeatedly satisfy the
/// "reset detected" check (`lastPercentage > 0 && current == 0`) on every refresh cycle.
struct NotificationState: Codable, Equatable, Sendable {
    /// Has the warning threshold notification been fired since utilization last dropped below
    /// the threshold, keyed by account id.
    var hasWarningBeenNotified: [UUID: Bool] = [:]

    /// Has the critical threshold notification been fired since utilization last dropped below
    /// the threshold, keyed by account id.
    var hasCriticalBeenNotified: [UUID: Bool] = [:]

    /// Last observed session utilization (0-100) per account — used to detect the 5-hour
    /// session reset (transition from > 0 to == 0).
    var lastSessionPercentageByAccount: [UUID: Double] = [:]

    enum CodingKeys: String, CodingKey {
        case hasWarningBeenNotified = "warning_notified_by_account"
        case hasCriticalBeenNotified = "critical_notified_by_account"
        case lastSessionPercentageByAccount = "last_session_percentage_by_account"
    }

    init(
        hasWarningBeenNotified: [UUID: Bool] = [:],
        hasCriticalBeenNotified: [UUID: Bool] = [:],
        lastSessionPercentageByAccount: [UUID: Double] = [:]
    ) {
        self.hasWarningBeenNotified = hasWarningBeenNotified
        self.hasCriticalBeenNotified = hasCriticalBeenNotified
        self.lastSessionPercentageByAccount = lastSessionPercentageByAccount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hasWarningBeenNotified = try container.decodeIfPresent([UUID: Bool].self, forKey: .hasWarningBeenNotified) ?? [:]
        hasCriticalBeenNotified = try container.decodeIfPresent([UUID: Bool].self, forKey: .hasCriticalBeenNotified) ?? [:]
        lastSessionPercentageByAccount = try container.decodeIfPresent([UUID: Double].self, forKey: .lastSessionPercentageByAccount) ?? [:]
        // Legacy single-account fields (warning_notified, critical_notified, last_percentage)
        // are intentionally dropped on upgrade — they were the source of the cross-account
        // false-positive reset spam this struct was rewritten to fix. There's no safe migration
        // path (we can't attribute a global percentage to a specific account), so the
        // per-account dictionaries simply start empty after upgrade.
    }
}

extension NotificationState {
    /// Check if a warning- or critical-threshold notification should fire for this account.
    func shouldNotify(
        accountId: UUID,
        currentPercentage: Double,
        threshold: Double,
        isWarning: Bool
    ) -> Bool {
        let alreadyNotified = isWarning
            ? (hasWarningBeenNotified[accountId] ?? false)
            : (hasCriticalBeenNotified[accountId] ?? false)
        return !alreadyNotified && currentPercentage >= threshold
    }

    /// Detect the 5-hour session reset for this account (utilization went from > 0 to 0).
    func shouldNotifyReset(accountId: UUID, currentPercentage: Double) -> Bool {
        let last = lastSessionPercentageByAccount[accountId] ?? 0
        return last > 0 && currentPercentage == 0
    }
}
