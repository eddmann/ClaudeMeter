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

                // Status badge
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

            // Usage percentage
            Text("\(Int(usageLimit.percentage))%")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(usageLimit.status.color)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))

                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(usageLimit.status.color)
                        .frame(width: geometry.size.width * min(usageLimit.percentage / 100, 1.0))
                }
            }
            .frame(height: 8)

            // Reset time and pacing indicator
            HStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text("Resets \(usageLimit.resetDescription)")
                        .font(.caption)
                }
                .help(usageLimit.resetTimeFormatted)

                Spacer()

                if let windowDuration,
                   usageLimit.isAtRisk(windowDuration: windowDuration) {
                    Image(systemName: "flame.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .help("You may hit your limit before it resets")
                        .accessibilityLabel("At risk of hitting limit")
                }
            }
            .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(Int(usageLimit.percentage))% used, \(usageLimit.status.accessibilityDescription)")
        .accessibilityValue("Resets \(usageLimit.resetDescription)")
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
