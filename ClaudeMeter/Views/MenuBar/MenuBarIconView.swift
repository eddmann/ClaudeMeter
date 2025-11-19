//
//  MenuBarIconView.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-14.
//

import SwiftUI

/// SwiftUI view for menu bar icon with battery-style indicator
struct MenuBarIconView: View {
    let percentage: Double
    let status: UsageStatus
    let isLoading: Bool
    let isStale: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text("Claude")
                .foregroundColor(statusColor)
                .font(.footnote)
            
            // Battery-style progress indicator
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Battery outline
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(statusColor, lineWidth: 1.5)

                    // Fill level
                    RoundedRectangle(cornerRadius: 1)
                        .fill(statusColor)
                        .frame(width: geometry.size.width * min(percentage / 100, 1.0))
                }
            }
            .frame(width: 24, height: 12)

            if isLoading {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(statusColor)
            } else {
                Text("\(Int(percentage))%")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(statusColor)
            }

            if isStale && !isLoading {
                Image(systemName: "exclamationmark.triangle.fill")
                   .font(.system(size: 8))
                   .foregroundColor(statusColor)
            }
        }
        .frame(height: 22)
        .padding(.horizontal, 6)
        .accessibilityLabel("Usage: \(Int(percentage)) percent")
        .accessibilityValue(status.accessibilityDescription)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Click to view detailed usage information")
    }

    private var statusColor: Color {
        if isStale {
            return .gray
        }
        return status.color
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        MenuBarIconView(percentage: 35, status: .safe, isLoading: false, isStale: false)
        MenuBarIconView(percentage: 65, status: .warning, isLoading: false, isStale: false)
        MenuBarIconView(percentage: 92, status: .critical, isLoading: false, isStale: false)
        MenuBarIconView(percentage: 45, status: .safe, isLoading: true, isStale: false)
        MenuBarIconView(percentage: 45, status: .safe, isLoading: false, isStale: true)
    }
    .padding()
}
