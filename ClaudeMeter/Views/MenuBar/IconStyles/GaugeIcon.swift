//
//  GaugeIcon.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-12-28.
//

import SwiftUI

/// Gauge-style menu bar icon using SF Symbols
struct GaugeIcon: View {
    let percentage: Double
    let status: UsageStatus
    let isLoading: Bool
    let isStale: Bool

    var body: some View {
        HStack(spacing: 4) {
            if isLoading {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(statusColor)
            } else {
                Image(systemName: symbolName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(statusColor)
                    .symbolRenderingMode(.hierarchical)
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

    /// Select appropriate gauge symbol based on percentage
    /// Aligned with UsageStatus thresholds from Constants.Thresholds.Status
    private var symbolName: String {
        let warning = Constants.Thresholds.Status.warningStart
        let critical = Constants.Thresholds.Status.criticalStart
        let midWarning = (warning + critical) / 2  // Midpoint of warning range

        switch percentage {
        case 0..<(warning * 0.6):  // Low safe range
            return "gauge.with.dots.needle.0percent"
        case 0..<warning:  // High safe range
            return "gauge.with.dots.needle.33percent"
        case warning..<midWarning:  // Low warning range
            return "gauge.with.dots.needle.50percent"
        case midWarning..<critical:  // High warning range
            return "gauge.with.dots.needle.67percent"
        default:  // Critical range
            return "gauge.with.dots.needle.100percent"
        }
    }

    private var statusColor: Color {
        isStale ? .gray : status.color
    }
}

#Preview {
    HStack(spacing: 20) {
        GaugeIcon(percentage: 10, status: .safe, isLoading: false, isStale: false)
        GaugeIcon(percentage: 30, status: .safe, isLoading: false, isStale: false)
        GaugeIcon(percentage: 50, status: .warning, isLoading: false, isStale: false)
        GaugeIcon(percentage: 70, status: .warning, isLoading: false, isStale: false)
        GaugeIcon(percentage: 90, status: .critical, isLoading: false, isStale: false)
        GaugeIcon(percentage: 45, status: .safe, isLoading: true, isStale: false)
        GaugeIcon(percentage: 45, status: .safe, isLoading: false, isStale: true)
    }
    .padding()
}
