//
//  MenuBarIconView.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-14.
//

import SwiftUI

/// SwiftUI view for menu bar icon with configurable style
struct MenuBarIconView: View {
    let percentage: Double
    let status: UsageStatus
    let isLoading: Bool
    let isStale: Bool
    let iconStyle: IconStyle
    var weeklyPercentage: Double = 0  // Optional, used by dualBar style
    var paceKind: PaceKind?  // Optional off-pace badge (flame/snowflake)
    var paceRatio: Double?  // Pace-first display: replaces the quota text with this ratio

    private var paceText: String? {
        paceRatio.map { String(format: "%.1f×", $0) }
    }

    /// Compact variant without the multiply sign, for the tiny circular gauge center
    private var compactPaceText: String? {
        paceRatio.map { String(format: "%.1f", $0) }
    }

    private var paceColor: Color? {
        paceRatio.map(PacePalette.color(for:))
    }

    /// Off-pace badge color: grayed out when data is stale (matching the rest of
    /// the icon), otherwise the shared pace scale so a heavy overuse reads red like
    /// the popover rather than a fixed orange.
    private func badgeColor(for kind: PaceKind) -> Color {
        if isStale { return .gray }
        return paceColor ?? (kind == .hot ? .orange : .blue)
    }

    var body: some View {
        HStack(spacing: 2) {
            styleView

            if let paceKind, !isLoading {
                Image(systemName: paceKind == .hot ? "flame.fill" : "snowflake")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(badgeColor(for: paceKind))
                    .accessibilityLabel(
                        paceKind == .hot
                            ? "Burning faster than sustainable pace"
                            : "Weekly quota may go unused"
                    )
            }
        }
    }

    @ViewBuilder
    private var styleView: some View {
        switch iconStyle {
        case .battery:
            BatteryIcon(percentage: percentage, status: status, isLoading: isLoading, isStale: isStale, overrideText: paceText, overrideColor: paceColor)
        case .circular:
            CircularGaugeIcon(percentage: percentage, status: status, isLoading: isLoading, isStale: isStale, overrideText: compactPaceText, overrideColor: paceColor)
        case .minimal:
            MinimalIcon(percentage: percentage, status: status, isLoading: isLoading, isStale: isStale, overrideText: paceText, overrideColor: paceColor)
        case .segments:
            SegmentedBarIcon(percentage: percentage, status: status, isLoading: isLoading, isStale: isStale, overrideColor: paceColor)
        case .dualBar:
            DualBarIcon(percentage: percentage, weeklyPercentage: weeklyPercentage, status: status, isLoading: isLoading, isStale: isStale, overrideText: paceText, overrideColor: paceColor)
        case .gauge:
            GaugeIcon(percentage: percentage, status: status, isLoading: isLoading, isStale: isStale, overrideColor: paceColor)
        }
    }
}

// MARK: - Preview

#Preview("All Styles") {
    VStack(alignment: .leading, spacing: 12) {
        ForEach(IconStyle.allCases) { style in
            HStack {
                Text(style.displayName)
                    .frame(width: 80, alignment: .leading)
                MenuBarIconView(percentage: 65, status: .warning, isLoading: false, isStale: false, iconStyle: style, weeklyPercentage: 45)
            }
        }
    }
    .padding()
}

#Preview("Battery States") {
    VStack(spacing: 20) {
        MenuBarIconView(percentage: 35, status: .safe, isLoading: false, isStale: false, iconStyle: .battery)
        MenuBarIconView(percentage: 65, status: .warning, isLoading: false, isStale: false, iconStyle: .battery)
        MenuBarIconView(percentage: 92, status: .critical, isLoading: false, isStale: false, iconStyle: .battery)
        MenuBarIconView(percentage: 45, status: .safe, isLoading: true, isStale: false, iconStyle: .battery)
        MenuBarIconView(percentage: 45, status: .safe, isLoading: false, isStale: true, iconStyle: .battery)
    }
    .padding()
}
