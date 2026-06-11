//
//  UsageLimit.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-14.
//

import Foundation

/// A single usage limit (session, weekly, or Sonnet)
struct UsageLimit: Codable, Equatable, Sendable {
    /// Utilization percentage (0-100)
    let utilization: Double

    /// ISO8601 timestamp when limit resets
    let resetAt: Date

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetAt = "reset_at"
    }
}

extension UsageLimit {
    /// Percentage used (0-100+) - alias for utilization
    var percentage: Double {
        utilization
    }

    /// Status level based on percentage
    /// Uses thresholds from Constants.Thresholds.Status
    var status: UsageStatus {
        switch utilization {
        case 0..<Constants.Thresholds.Status.warningStart:
            return .safe
        case Constants.Thresholds.Status.warningStart..<Constants.Thresholds.Status.criticalStart:
            return .warning
        default:
            return .critical
        }
    }

    /// Human-readable reset time, rounded up to avoid understating remaining time.
    var resetDescription: String {
        Self.resetDescription(for: resetAt.timeIntervalSinceNow)
    }

    static func resetDescription(for remaining: TimeInterval) -> String {
        guard remaining > 0 else {
            return "now"
        }

        let minute: TimeInterval = 60
        let hour: TimeInterval = 60 * minute
        let day: TimeInterval = 24 * hour

        if remaining < hour {
            let minutes = max(1, Int(ceil(remaining / minute)))
            return "in \(minutes) \(Self.unit("minute", count: minutes))"
        }

        if remaining < day {
            let hours = Int(ceil(remaining / hour))
            return "in \(hours) \(Self.unit("hour", count: hours))"
        }

        let roundedHours = Int(ceil(remaining / hour))
        let days = roundedHours / 24
        let hours = roundedHours % 24

        if hours == 0 {
            return "in \(days) \(Self.unit("day", count: days))"
        }

        return "in \(days) \(Self.unit("day", count: days)) \(hours) \(Self.unit("hour", count: hours))"
    }

    private static func unit(_ singular: String, count: Int) -> String {
        count == 1 ? singular : "\(singular)s"
    }

    /// Exact reset time formatted in user's timezone for tooltip display (no year)
    var resetTimeFormatted: String {
        let formatter = DateFormatter()
        formatter.timeZone = .current
        formatter.setLocalizedDateFormatFromTemplate("MMMdjmm")
        return formatter.string(from: resetAt)
    }

    /// Exact reset time-of-day only (no date), in the user's timezone.
    var resetTimeOnlyFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        formatter.timeZone = .current
        return formatter.string(from: resetAt)
    }

    /// Check if limit has been exceeded
    var isExceeded: Bool {
        utilization >= 100
    }

    /// Check if reset time has passed but usage hasn't reset
    var isResetting: Bool {
        resetAt < Date() && utilization > 0
    }

    /// Returns true if current usage rate will likely exceed limit before reset
    /// - Parameter windowDuration: Duration of the usage window (e.g., 5 hours for session)
    func isAtRisk(windowDuration: TimeInterval) -> Bool {
        let now = Date()
        guard resetAt > now else { return false }

        let windowStart = resetAt.addingTimeInterval(-windowDuration)
        let elapsed = now.timeIntervalSince(windowStart)
        guard elapsed > 0 else { return false }

        let timeElapsedPct = elapsed / windowDuration
        let usagePct = min(utilization, 100) / 100
        guard timeElapsedPct > 0 else { return false }

        return (usagePct / timeElapsedPct) > Constants.Pacing.riskThreshold
    }
}
