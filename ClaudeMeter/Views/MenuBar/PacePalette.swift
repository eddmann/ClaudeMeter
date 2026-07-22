//
//  PacePalette.swift
//  ClaudeMeter
//
//  Created by Edd on 2026-07-17.
//

import SwiftUI

/// Shared color scale for pace ratios, used by the menu bar and popover alike
enum PacePalette {
    /// Discrete pace band a ratio falls into. The single source of truth for the
    /// ratio thresholds so color, cache keys, and callers can't drift apart.
    enum Band: String {
        case underuse, sustainable, overuse, heavyOveruse
    }

    /// Blue underuse (<0.8x), green sustainable (0.8-1.0x),
    /// orange overuse (1.0-1.2x), red heavy overuse (>1.2x)
    static func band(for ratio: Double) -> Band {
        if ratio < Constants.Pacing.underuseThreshold { return .underuse }
        if ratio <= Constants.Pacing.riskThreshold { return .sustainable }
        if ratio <= Constants.Pacing.heavyOveruseThreshold { return .overuse }
        return .heavyOveruse
    }

    static func color(for ratio: Double) -> Color {
        switch band(for: ratio) {
        case .underuse: return .blue
        case .sustainable: return .green
        case .overuse: return .orange
        case .heavyOveruse: return .red
        }
    }
}

/// Shared resolution of an icon label's color across the menu bar icon styles:
/// gray when stale, the pace override color when one is active, else quota status.
enum IconPalette {
    static func textColor(isStale: Bool, override: Color?, status: UsageStatus) -> Color {
        if isStale { return .gray }
        if let override { return override }
        return status.color
    }
}
