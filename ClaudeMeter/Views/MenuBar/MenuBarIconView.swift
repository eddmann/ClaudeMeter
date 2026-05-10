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
    /// When false, the icon is drawn with pure black so the rendered NSImage can be used as a
    /// template image and tinted by macOS (white on dark menu bars, black on light).
    var useColor: Bool = true

    var body: some View {
        switch iconStyle {
        case .battery:
            BatteryIcon(percentage: percentage, status: status, isLoading: isLoading, isStale: isStale, useColor: useColor)
        case .circular:
            CircularGaugeIcon(percentage: percentage, status: status, isLoading: isLoading, isStale: isStale, useColor: useColor)
        case .minimal:
            MinimalIcon(percentage: percentage, status: status, isLoading: isLoading, isStale: isStale, useColor: useColor)
        case .segments:
            SegmentedBarIcon(percentage: percentage, status: status, isLoading: isLoading, isStale: isStale, useColor: useColor)
        case .dualBar:
            DualBarIcon(percentage: percentage, weeklyPercentage: weeklyPercentage, status: status, isLoading: isLoading, isStale: isStale, useColor: useColor)
        case .gauge:
            GaugeIcon(percentage: percentage, status: status, isLoading: isLoading, isStale: isStale, useColor: useColor)
        }
    }
}

/// Centralised colour resolution for the menu bar icons.
///
/// In monochrome mode every drawn pixel is black so the resulting NSImage can be rendered as a
/// template image (`NSImage.isTemplate = true`) and tinted by the system menu bar — white on
/// dark menu bars, black on light. In colour mode the original status palette is preserved.
enum MenuBarIconColors {
    static func text(useColor: Bool, status: UsageStatus, isStale: Bool) -> Color {
        if isStale { return .gray }
        return useColor ? status.color : .black
    }

    static func fill(useColor: Bool, status: UsageStatus, isStale: Bool) -> Color {
        if isStale { return .gray }
        return useColor ? status.color : .black
    }

    /// Track / background. Matches the original gray track in colour mode (snapshot tests
    /// are pixel-perfect). In monochrome mode it uses a black track so template rendering
    /// tints it correctly.
    static func track(useColor: Bool) -> Color {
        useColor ? Color.gray.opacity(0.3) : Color.black.opacity(0.3)
    }

    static func gradient(useColor: Bool, isStale: Bool) -> LinearGradient {
        if isStale {
            return LinearGradient(colors: [.gray, .gray], startPoint: .leading, endPoint: .trailing)
        }
        if useColor {
            return LinearGradient(colors: [.green, .yellow, .orange, .red], startPoint: .leading, endPoint: .trailing)
        }
        return LinearGradient(colors: [.black, .black], startPoint: .leading, endPoint: .trailing)
    }

    /// Secondary accent (e.g. weekly bar in DualBar). Purple in colour mode, black in monochrome.
    static func secondary(useColor: Bool, isStale: Bool) -> Color {
        if isStale { return .gray }
        return useColor ? .purple : .black
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

#Preview("Monochrome") {
    VStack(alignment: .leading, spacing: 12) {
        ForEach(IconStyle.allCases) { style in
            HStack {
                Text(style.displayName)
                    .frame(width: 80, alignment: .leading)
                MenuBarIconView(percentage: 65, status: .warning, isLoading: false, isStale: false, iconStyle: style, weeklyPercentage: 45, useColor: false)
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
