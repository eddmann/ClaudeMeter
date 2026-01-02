//
//  BatteryIcon.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-12-28.
//

import SwiftUI

/// Battery-style menu bar icon with gradient fill
struct BatteryIcon: View {
    let percentage: Double
    let status: UsageStatus
    let isLoading: Bool
    let isStale: Bool

    private let capsuleWidth: CGFloat = 28
    private let capsuleHeight: CGFloat = 10

    var body: some View {
        HStack(spacing: 4) {
            if isLoading {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(statusColor)
            } else {
                // Capsule with gradient fill using mask for proper rounded ends
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(alignment: .leading) {
                        GeometryReader { geo in
                            fillGradient
                                .frame(width: geo.size.width * min(percentage / 100, 1.0))
                        }
                        .clipShape(Capsule())
                    }
                    .frame(width: capsuleWidth, height: capsuleHeight)

                // Percentage text
                Text("\(Int(percentage))%") 
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(statusColor)
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

    private var fillGradient: LinearGradient {
        if isStale {
            return LinearGradient(
                colors: [.gray, .gray],
                startPoint: .leading,
                endPoint: .trailing
            )
        }

        // Gradient shows current status position
        return LinearGradient(
            colors: [.green, .yellow, .orange, .red],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var statusColor: Color {
        isStale ? .gray : status.color
    }
}

#Preview {
    HStack(spacing: 20) {
        BatteryIcon(percentage: 25, status: .safe, isLoading: false, isStale: false)
        BatteryIcon(percentage: 50, status: .warning, isLoading: false, isStale: false)
        BatteryIcon(percentage: 75, status: .warning, isLoading: false, isStale: false)
        BatteryIcon(percentage: 95, status: .critical, isLoading: false, isStale: false)
        BatteryIcon(percentage: 45, status: .safe, isLoading: true, isStale: false)
        BatteryIcon(percentage: 45, status: .safe, isLoading: false, isStale: true)
    }
    .padding()
}
