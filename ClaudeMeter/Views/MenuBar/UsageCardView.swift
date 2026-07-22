//
//  UsageCardView.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-14.
//

import SwiftUI

/// Reusable usage card component
struct UsageCardView: View {
    let title: String
    let usageLimit: UsageLimit
    let icon: String
    let windowDuration: TimeInterval?
    var pacingDuration: TimeInterval?  // Optional shorter span the quota is expected to be consumed over
    var showsUnderuse: Bool = false  // Whether underuse is a meaningful signal for this window (weekly, not session)
    var isPaceFirst: Bool = false  // Pace as primary display, quota as secondary

    private var paceRatio: Double? {
        guard let windowDuration else { return nil }
        return usageLimit.paceRatio(windowDuration: windowDuration, pacingDuration: pacingDuration)
    }

    private var expectedPercent: Double? {
        guard let windowDuration else { return nil }
        return usageLimit.expectedUsagePercent(windowDuration: windowDuration, pacingDuration: pacingDuration)
    }

    /// Bar fill color: pace scale in pace-first mode, quota status otherwise
    private var barColor: Color {
        if isPaceFirst, let paceRatio {
            return PacePalette.color(for: paceRatio)
        }
        return usageLimit.status.color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with icon and title
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(usageLimit.status.color)

                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                // Status badge: pace verdict in pace-first mode, quota status otherwise
                if isPaceFirst, let paceRatio {
                    let verdict = Self.paceVerdict(for: paceRatio)
                    HStack(spacing: 4) {
                        Image(systemName: verdict.icon)
                            .font(.caption)
                        Text(verdict.label)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(verdict.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(verdict.color.opacity(0.15))
                    .cornerRadius(8)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: usageLimit.status.iconName)
                            .font(.caption)
                        Text(usageLimit.status.rawValue.capitalized)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(usageLimit.status.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(usageLimit.status.color.opacity(0.15))
                    .cornerRadius(8)
                }
            }

            // Primary number: pace ratio in pace-first mode, quota percentage otherwise
            HStack(alignment: .lastTextBaseline) {
                if isPaceFirst, let paceRatio {
                    Text(String(format: "%.1f×", paceRatio))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(Self.paceVerdict(for: paceRatio).color)

                    Spacer()

                    // Quota usage as secondary detail
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(usageLimit.percentage))% used")
                            .font(.caption)
                            .foregroundColor(usageLimit.status.color)
                        if let expectedPercent {
                            Text("\(Int(expectedPercent.rounded()))% expected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Text("\(Int(usageLimit.percentage))%")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(usageLimit.status.color)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        if let expectedPercent {
                            Text("\(Int(expectedPercent.rounded()))% expected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        paceLine
                    }
                }
            }

            // Progress bar with expected-pace tick
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))

                    // Progress (pace-colored in pace-first mode, quota-status otherwise)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor)
                        .frame(width: geometry.size.width * min(usageLimit.percentage / 100, 1.0))

                    // Expected-by-now tick
                    if let expectedPercent {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.primary.opacity(0.55))
                            .frame(width: 2, height: 14)
                            .offset(x: geometry.size.width * min(expectedPercent / 100, 1.0) - 1)
                    }
                }
            }
            .frame(height: 8)

            // Projection at the current rate
            projectionLine

            // Reset time
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption)
                Text("Resets \(usageLimit.resetDescription)")
                    .font(.caption)
            }
            .help(usageLimit.resetTimeFormatted)
            .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(Int(usageLimit.percentage))% used, \(usageLimit.status.accessibilityDescription)")
        .accessibilityValue("Resets \(usageLimit.resetDescription)")
    }

    // MARK: - Pace

    @ViewBuilder
    private var paceLine: some View {
        if let paceRatio {
            let formatted = String(format: "%.1f×", paceRatio)
            HStack(spacing: 3) {
                if paceRatio > Constants.Pacing.riskThreshold {
                    Image(systemName: "flame.fill")
                } else if paceRatio < Constants.Pacing.underuseThreshold {
                    Image(systemName: "snowflake")
                }
                Text("\(formatted) pace")
            }
            .font(.caption)
            .foregroundColor(PacePalette.color(for: paceRatio))
            .accessibilityLabel("\(formatted) sustainable pace")
        }
    }

    @ViewBuilder
    private var projectionLine: some View {
        if usageLimit.isExceeded {
            Text("Limit reached")
                .font(.caption)
                .foregroundColor(.red)
        } else if let windowDuration {
            if let hitDate = usageLimit.projectedLimitDate(windowDuration: windowDuration, pacingDuration: pacingDuration) {
                Text("Hits limit ~\(Self.hitDateDescription(hitDate)), \(Self.remainingDescription(usageLimit.resetAt.timeIntervalSince(hitDate))) before reset")
                    .font(.caption)
                    .foregroundColor(paceRatio.map(PacePalette.color(for:)) ?? .orange)
            } else if let endPercent = usageLimit.projectedEndPercent(windowDuration: windowDuration, pacingDuration: pacingDuration) {
                let end = Int(min(endPercent, 100).rounded())
                if showsUnderuse, let paceRatio, paceRatio < Constants.Pacing.underuseThreshold {
                    Text("On pace to end at ~\(end)% (\(100 - end)% unused)")
                        .font(.caption)
                        .foregroundColor(.blue)
                } else {
                    Text("On pace to end at ~\(end)%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    /// Pace verdict presentation for pace-first mode
    static func paceVerdict(for ratio: Double) -> (label: String, icon: String, color: Color) {
        let color = PacePalette.color(for: ratio)
        if ratio > Constants.Pacing.riskThreshold {
            return ("Overusing", "flame.fill", color)
        }
        if ratio < Constants.Pacing.underuseThreshold {
            return ("Underusing", "snowflake", color)
        }
        return ("On Pace", "checkmark.circle.fill", color)
    }

    /// Time-of-day for a same-day hit; weekday/date + time when the projected hit
    /// is days out (weekly window), so a multi-day projection isn't shown as a bare
    /// clock time that reads like today.
    static func hitDateDescription(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = Calendar.current.isDateInToday(date) ? .none : .short
        formatter.doesRelativeDateFormatting = true
        return formatter.string(from: date)
    }

    /// "in 50 minutes" -> "50 minutes"
    private static func remainingDescription(_ interval: TimeInterval) -> String {
        let description = UsageLimit.resetDescription(for: interval)
        return description.hasPrefix("in ") ? String(description.dropFirst(3)) : description
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        UsageCardView(
            title: "5-Hour Session",
            usageLimit: UsageLimit(
                utilization: 35.0,
                resetAt: Date().addingTimeInterval(7200)
            ),
            icon: "gauge.with.dots.needle.67percent",
            windowDuration: Constants.Pacing.sessionWindow
        )

        UsageCardView(
            title: "Weekly Usage",
            usageLimit: UsageLimit(
                utilization: 75.0,
                resetAt: Date().addingTimeInterval(86400 * 3)
            ),
            icon: "calendar",
            windowDuration: Constants.Pacing.weeklyWindow
        )
    }
    .padding()
    .frame(width: 320)
}
