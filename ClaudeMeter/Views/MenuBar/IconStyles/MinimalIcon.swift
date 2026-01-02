//
//  MinimalIcon.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-12-28.
//

import SwiftUI

/// Minimal percentage-only menu bar icon
struct MinimalIcon: View {
    let percentage: Double
    let status: UsageStatus
    let isLoading: Bool
    let isStale: Bool

    var body: some View {
        HStack(spacing: 2) {
            if isLoading {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(statusColor)
            } else {
                Text("\(Int(percentage))%")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
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

    private var statusColor: Color {
        isStale ? .gray : status.color
    }
}

#Preview {
    HStack(spacing: 20) {
        MinimalIcon(percentage: 35, status: .safe, isLoading: false, isStale: false)
        MinimalIcon(percentage: 65, status: .warning, isLoading: false, isStale: false)
        MinimalIcon(percentage: 92, status: .critical, isLoading: false, isStale: false)
        MinimalIcon(percentage: 45, status: .safe, isLoading: true, isStale: false)
        MinimalIcon(percentage: 45, status: .safe, isLoading: false, isStale: true)
    }
    .padding()
}
