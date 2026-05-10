//
//  DualBarIcon.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-12-28.
//

import SwiftUI

/// Dual bar menu bar icon showing session (top) and weekly (bottom) usage
struct DualBarIcon: View {
    let percentage: Double        // Session percentage
    let weeklyPercentage: Double  // Weekly percentage
    let status: UsageStatus
    let isLoading: Bool
    let isStale: Bool
    var useColor: Bool = true

    private let barWidth: CGFloat = 32
    private let barHeight: CGFloat = 5
    private let barSpacing: CGFloat = 2

    var body: some View {
        HStack(spacing: 4) {
            if isLoading {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(MenuBarIconColors.text(useColor: useColor, status: status, isStale: isStale))
            } else {
                // Two stacked progress bars
                VStack(spacing: barSpacing) {
                    // Session bar (top): status colour in colour mode, black in monochrome
                    ProgressBar(
                        percentage: percentage,
                        color: MenuBarIconColors.fill(useColor: useColor, status: status, isStale: isStale),
                        useColor: useColor
                    )
                    .frame(width: barWidth, height: barHeight)

                    // Weekly bar (bottom): purple in colour mode, black in monochrome
                    ProgressBar(
                        percentage: weeklyPercentage,
                        color: MenuBarIconColors.secondary(useColor: useColor, isStale: isStale),
                        useColor: useColor
                    )
                    .frame(width: barWidth, height: barHeight)
                }

                // Show session percentage (primary metric)
                Text("\(Int(percentage))%")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(MenuBarIconColors.text(useColor: useColor, status: status, isStale: isStale))
            }

            if isStale && !isLoading {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 8))
                    .foregroundColor(.gray)
            }
        }
        .frame(height: 22)
        .padding(.horizontal, 4)
        .accessibilityLabel("Session: \(Int(percentage)) percent, Weekly: \(Int(weeklyPercentage)) percent")
        .accessibilityValue(status.accessibilityDescription)
    }
}

/// Individual progress bar component
private struct ProgressBar: View {
    let percentage: Double
    let color: Color
    let useColor: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(MenuBarIconColors.track(useColor: useColor))

                // Fill
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(color)
                    .frame(width: geo.size.width * min(percentage / 100, 1.0))
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            DualBarIcon(percentage: 35, weeklyPercentage: 20, status: .safe, isLoading: false, isStale: false)
            DualBarIcon(percentage: 65, weeklyPercentage: 45, status: .warning, isLoading: false, isStale: false)
            DualBarIcon(percentage: 92, weeklyPercentage: 78, status: .critical, isLoading: false, isStale: false)
        }
        HStack(spacing: 20) {
            DualBarIcon(percentage: 45, weeklyPercentage: 30, status: .safe, isLoading: true, isStale: false)
            DualBarIcon(percentage: 45, weeklyPercentage: 30, status: .safe, isLoading: false, isStale: true)
        }
    }
    .padding()
}
