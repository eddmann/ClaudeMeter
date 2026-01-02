//
//  IconStylePicker.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-12-28.
//

import SwiftUI

/// Visual grid picker for selecting menu bar icon style
struct IconStylePicker: View {
    @Binding var selection: IconStyle
    var onSelectionChanged: ((IconStyle) -> Void)?

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(IconStyle.allCases) { style in
                IconStyleCard(
                    style: style,
                    isSelected: selection == style
                )
                .onTapGesture {
                    selection = style
                    onSelectionChanged?(style)
                }
            }
        }
    }
}

/// Individual card showing icon style preview
struct IconStyleCard: View {
    let style: IconStyle
    let isSelected: Bool

    /// Preview percentages to show
    private let previewPercentage: Double = 65
    private let previewWeeklyPercentage: Double = 45
    private let previewStatus: UsageStatus = .warning

    var body: some View {
        VStack(spacing: 8) {
            // Live preview container
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(NSColor.windowBackgroundColor))
                    .frame(height: 32)

                // Render the actual icon at a slightly larger scale for visibility
                iconPreview
                    .scaleEffect(1.2)
            }

            Text(style.displayName)
                .font(.caption)
                .foregroundColor(isSelected ? .accentColor : .primary)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.accentColor)
            } else {
                // Placeholder to maintain consistent height
                Image(systemName: "circle")
                    .font(.system(size: 14))
                    .foregroundColor(.clear)
            }
        }
        .padding(10)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(style.displayName) icon style")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
        .accessibilityHint(style.accessibilityDescription)
    }

    private var iconPreview: some View {
        MenuBarIconView(
            percentage: previewPercentage,
            status: previewStatus,
            isLoading: false,
            isStale: false,
            iconStyle: style,
            weeklyPercentage: previewWeeklyPercentage
        )
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var selection: IconStyle = .battery

        var body: some View {
            VStack {
                Text("Selected: \(selection.displayName)")
                    .padding()

                IconStylePicker(selection: $selection)
                    .padding()
            }
            .frame(width: 400)
        }
    }

    return PreviewWrapper()
}
