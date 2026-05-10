//
//  CircularGaugeIcon.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-12-28.
//

import SwiftUI

/// Circular gauge (donut) style menu bar icon
struct CircularGaugeIcon: View {
    let percentage: Double
    let status: UsageStatus
    let isLoading: Bool
    let isStale: Bool
    var useColor: Bool = true

    private let lineWidth: CGFloat = 3
    private let size: CGFloat = 18

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(MenuBarIconColors.track(useColor: useColor), lineWidth: lineWidth)

            // Progress arc
            Circle()
                .trim(from: 0, to: min(percentage / 100, 1.0))
                .stroke(MenuBarIconColors.fill(useColor: useColor, status: status, isStale: isStale), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            // Center percentage or loading indicator
            if isLoading {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(MenuBarIconColors.text(useColor: useColor, status: status, isStale: isStale))
            } else {
                Text("\(Int(percentage))")
                    .font(.system(size: 7, weight: .bold, design: .rounded))
                    .foregroundColor(MenuBarIconColors.text(useColor: useColor, status: status, isStale: isStale))
            }
        }
        .frame(width: size, height: size)
        .overlay(alignment: .topTrailing) {
            if isStale && !isLoading {
                Circle()
                    .fill(Color.gray)
                    .frame(width: 4, height: 4)
                    .offset(x: 2, y: -2)
            }
        }
        .frame(height: 22)
        .padding(.horizontal, 4)
        .accessibilityLabel("Usage: \(Int(percentage)) percent")
        .accessibilityValue(status.accessibilityDescription)
    }
}

#Preview {
    HStack(spacing: 20) {
        CircularGaugeIcon(percentage: 35, status: .safe, isLoading: false, isStale: false)
        CircularGaugeIcon(percentage: 65, status: .warning, isLoading: false, isStale: false)
        CircularGaugeIcon(percentage: 92, status: .critical, isLoading: false, isStale: false)
        CircularGaugeIcon(percentage: 45, status: .safe, isLoading: true, isStale: false)
        CircularGaugeIcon(percentage: 45, status: .safe, isLoading: false, isStale: true)
    }
    .padding()
}
