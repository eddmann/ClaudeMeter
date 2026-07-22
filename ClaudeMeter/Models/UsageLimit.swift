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

    /// Exact reset time formatted in user's timezone for tooltip display
    var resetTimeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
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

    /// Ratio of usage fraction to elapsed-time fraction of the window.
    /// 1.0 = exactly sustainable pace, >1 = burning faster, <1 = underusing.
    /// Returns nil when the window isn't active, or too little has elapsed and
    /// usage is still below `minimumUsageForProjection` (a front-loaded burst
    /// surfaces the ratio without waiting out the elapsed grace).
    /// - Parameters:
    ///   - windowDuration: Duration of the usage window (e.g., 5 hours for session)
    ///   - pacingDuration: Time span the quota is expected to be consumed over.
    ///     Defaults to the full window; a shorter span (e.g., 5 working days of a
    ///     7-day window) expects the quota to be burned faster. Elapsed time is
    ///     capped at the pacing duration, so past it the ratio equals the usage fraction.
    func paceRatio(windowDuration: TimeInterval, pacingDuration: TimeInterval? = nil) -> Double? {
        guard let expected = expectedUsagePercent(windowDuration: windowDuration, pacingDuration: pacingDuration) else {
            return nil
        }
        return min(utilization, 100) / expected
    }

    /// Utilization percentage the pace plan expects by now (0-100), i.e. the
    /// elapsed fraction of the pacing span. Returns nil under the same
    /// conditions as `paceRatio(windowDuration:pacingDuration:)`.
    func expectedUsagePercent(windowDuration: TimeInterval, pacingDuration: TimeInterval? = nil) -> Double? {
        let pacing = pacingDuration ?? windowDuration
        let now = Date()
        guard resetAt > now, pacing > 0 else { return nil }

        let windowStart = resetAt.addingTimeInterval(-windowDuration)
        let timeElapsedPct = min(now.timeIntervalSince(windowStart) / pacing, 1.0)
        // A front-loaded burst is meaningful before the elapsed grace: once usage
        // clears `minimumUsageForProjection` the ratio surfaces immediately, matching
        // `projectedLimitDate`. `timeElapsedPct > 0` keeps the ratio's divisor safe.
        guard timeElapsedPct > 0,
              timeElapsedPct >= Constants.Pacing.minimumElapsedFraction
                  || utilization >= Constants.Pacing.minimumUsageForProjection
        else { return nil }

        return timeElapsedPct * 100
    }

    /// Returns true if current usage rate will likely exceed limit before reset
    /// - Parameters:
    ///   - windowDuration: Duration of the usage window (e.g., 5 hours for session)
    ///   - pacingDuration: See `paceRatio(windowDuration:pacingDuration:)`
    func isAtRisk(windowDuration: TimeInterval, pacingDuration: TimeInterval? = nil) -> Bool {
        guard let ratio = paceRatio(windowDuration: windowDuration, pacingDuration: pacingDuration) else { return false }
        return ratio > Constants.Pacing.riskThreshold
    }

    /// Projected utilization percentage at the pacing deadline if the current
    /// average rate holds. Extrapolates to the pacing horizon (default: the full
    /// window) so it shares a time basis with `paceRatio` — a card can't then read
    /// "underusing" and "hits limit" at once. Returns nil when the window isn't
    /// active, or too little has elapsed and usage is below
    /// `minimumUsageForProjection`.
    /// - Parameters:
    ///   - windowDuration: Duration of the usage window (e.g., 5 hours for session)
    ///   - pacingDuration: See `paceRatio(windowDuration:pacingDuration:)`
    func projectedEndPercent(windowDuration: TimeInterval, pacingDuration: TimeInterval? = nil) -> Double? {
        let now = Date()
        guard resetAt > now else { return nil }

        let windowStart = resetAt.addingTimeInterval(-windowDuration)
        let elapsed = now.timeIntervalSince(windowStart)
        guard elapsed > 0 else { return nil }
        // As with `projectedLimitDate`, a burst clearing `minimumUsageForProjection`
        // projects immediately instead of waiting out the elapsed grace window.
        guard elapsed >= windowDuration * Constants.Pacing.minimumElapsedFraction
                  || utilization >= Constants.Pacing.minimumUsageForProjection
        else { return nil }

        // Never project a horizon shorter than what's already elapsed.
        let horizon = max(pacingDuration ?? windowDuration, elapsed)
        return utilization * (horizon / elapsed)
    }

    /// When the limit will be hit at the current average rate, if that lands on or
    /// before the pacing deadline. Returns nil if usage won't reach 100% in time
    /// (or already has). Unlike `projectedEndPercent`, this fires as soon as usage
    /// clears `minimumUsageForProjection` — a genuine front-loaded burst warns
    /// immediately rather than waiting out the elapsed-time grace window.
    func projectedLimitDate(windowDuration: TimeInterval, pacingDuration: TimeInterval? = nil) -> Date? {
        let now = Date()
        guard !isExceeded, utilization >= Constants.Pacing.minimumUsageForProjection, resetAt > now else {
            return nil
        }

        let windowStart = resetAt.addingTimeInterval(-windowDuration)
        let elapsed = now.timeIntervalSince(windowStart)
        guard elapsed > 0 else { return nil }

        let hitDate = windowStart.addingTimeInterval(elapsed * 100 / utilization)
        let deadline = windowStart.addingTimeInterval(max(pacingDuration ?? windowDuration, elapsed))
        guard hitDate < deadline else { return nil }
        return hitDate
    }
}
