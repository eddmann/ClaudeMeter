//
//  SegmentedBarIcon.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-12-28.
//

import SwiftUI

/// Segmented bar (signal strength style) menu bar icon
struct SegmentedBarIcon: View {
    let percentage: Double
    let status: UsageStatus
    let isLoading: Bool
    let isStale: Bool
    var useColor: Bool = true

    private let segmentCount = 5
    private let segmentWidth: CGFloat = 4
    private let segmentSpacing: CGFloat = 2

    var body: some View {
        HStack(spacing: 2) {
            if isLoading {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(MenuBarIconColors.text(useColor: useColor, status: status, isStale: isStale))
            } else {
                HStack(spacing: segmentSpacing) {
                    ForEach(0..<segmentCount, id: \.self) { index in
                        let threshold = Double(index + 1) * (100.0 / Double(segmentCount))
                        let isActive = percentage >= threshold - (100.0 / Double(segmentCount))

                        RoundedRectangle(cornerRadius: 1)
                            .fill(isActive ? segmentColor(for: index) : MenuBarIconColors.track(useColor: useColor))
                            .frame(width: segmentWidth, height: segmentHeight(for: index))
                    }
                }
                .frame(height: 14, alignment: .bottom)
            }

            if isStale && !isLoading {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 8))
                    .foregroundColor(.gray)
            }
        }
        .frame(height: 22)
        .padding(.horizontal, 4)
        .accessibilityLabel("Usage: \(Int(percentage)) percent")
        .accessibilityValue(status.accessibilityDescription)
    }

    private func segmentHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 6
        let increment: CGFloat = 2
        return baseHeight + (CGFloat(index) * increment)
    }

    private func segmentColor(for index: Int) -> Color {
        if isStale { return .gray }
        if !useColor { return .black }
        // Color segments by position to create a gradient effect (green → orange → red)
        // Uses Constants.Thresholds.Status for consistent color boundaries
        let segmentPercentage = Double(index + 1) / Double(segmentCount) * 100
        if segmentPercentage <= Constants.Thresholds.Status.warningStart {
            return .green
        } else if segmentPercentage <= Constants.Thresholds.Status.criticalStart {
            return .orange
        } else {
            return .red
        }
    }
}

#Preview {
    HStack(spacing: 20) {
        SegmentedBarIcon(percentage: 20, status: .safe, isLoading: false, isStale: false)
        SegmentedBarIcon(percentage: 45, status: .safe, isLoading: false, isStale: false)
        SegmentedBarIcon(percentage: 65, status: .warning, isLoading: false, isStale: false)
        SegmentedBarIcon(percentage: 92, status: .critical, isLoading: false, isStale: false)
        SegmentedBarIcon(percentage: 45, status: .safe, isLoading: true, isStale: false)
        SegmentedBarIcon(percentage: 45, status: .safe, isLoading: false, isStale: true)
    }
    .padding()
}
