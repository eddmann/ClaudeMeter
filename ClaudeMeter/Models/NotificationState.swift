//
//  NotificationState.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-14.
//

import Foundation

/// Tracks which notification thresholds have been triggered
struct NotificationState: Codable, Equatable, Sendable {
    var hasWarningBeenNotified: Bool = false
    var hasCriticalBeenNotified: Bool = false

    /// Last known usage percentage to detect reset
    var lastPercentage: Double = 0

    /// Name of the limit the fields above describe (nil in state saved before this was added,
    /// when the 5-hour session was always tracked)
    var trackedLimit: String?

    enum CodingKeys: String, CodingKey {
        case hasWarningBeenNotified = "warning_notified"
        case hasCriticalBeenNotified = "critical_notified"
        case lastPercentage = "last_percentage"
        case trackedLimit = "tracked_limit"
    }
}

extension NotificationState {
    /// Start fresh when the tracked limit changes (e.g. the 5-hour limit disappears),
    /// so one limit's flags and last percentage aren't applied to another
    mutating func switchTrackedLimit(to limitName: String, currentPercentage: Double) {
        let previousLimit = trackedLimit ?? UsageData.sessionLimitName
        trackedLimit = limitName
        guard previousLimit != limitName else { return }
        hasWarningBeenNotified = false
        hasCriticalBeenNotified = false
        lastPercentage = currentPercentage
    }

    /// Reset tracking when usage drops below thresholds
    mutating func resetIfNeeded(currentPercentage: Double, warningThreshold: Double, criticalThreshold: Double) {
        if currentPercentage < warningThreshold {
            hasWarningBeenNotified = false
        }
        if currentPercentage < criticalThreshold {
            hasCriticalBeenNotified = false
        }
        lastPercentage = currentPercentage
    }

    /// Check if threshold should trigger notification
    func shouldNotify(
        currentPercentage: Double,
        threshold: Double,
        isWarning: Bool
    ) -> Bool {
        // Check if crossing warning threshold
        if isWarning && !hasWarningBeenNotified && currentPercentage >= threshold {
            return true
        }
        // Check if crossing critical threshold
        if !isWarning && !hasCriticalBeenNotified && currentPercentage >= threshold {
            return true
        }
        return false
    }

    /// Check if session reset should trigger notification
    func shouldNotifyReset(currentPercentage: Double) -> Bool {
        lastPercentage > 0 && currentPercentage == 0
    }
}
