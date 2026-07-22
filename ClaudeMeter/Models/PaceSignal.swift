//
//  PaceSignal.swift
//  ClaudeMeter
//
//  Created by Edd on 2026-07-17.
//

import Foundation

/// Direction of an off-pace burn rate
enum PaceKind: String, Sendable {
    /// Burning faster than sustainable - likely to hit the limit before reset
    case hot
    /// Underusing - quota likely to go unused before reset
    case cold
}

/// An off-pace signal for menu bar display, naming the window that produced it
struct PaceSignal: Equatable, Sendable {
    let kind: PaceKind

    /// Usage fraction divided by elapsed-time fraction (1.0 = sustainable pace)
    let ratio: Double

    /// Human-readable window name (e.g. "5-hour", "7-day")
    let windowName: String

    /// Actual utilization percentage
    let usedPercent: Double

    /// Utilization percentage the pace plan expected by now
    let expectedPercent: Double

    /// Weekly pace basis in days, when the quota is paced over fewer days than the window
    var paceDays: Int?
}

extension PaceSignal {
    /// Tooltip text explaining the signal and which window drives it
    var tooltip: String {
        let used = Int(usedPercent.rounded())
        let expected = Int(expectedPercent.rounded())
        let formattedRatio = String(format: "%.1f", ratio)
        let window: String
        if let paceDays, paceDays != 7 {
            window = "\(paceDays)/7-day window"
        } else {
            window = "\(windowName) window"
        }

        switch kind {
        case .hot:
            return "Used \(used)% vs \(expected)% expected by now - burning \(formattedRatio)× sustainable pace (\(window))"
        case .cold:
            return "Used \(used)% vs \(expected)% expected by now - \(formattedRatio)× pace, quota may go unused (\(window))"
        }
    }
}
