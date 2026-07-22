//
//  DisplayModePicker.swift
//  ClaudeMeter
//
//  Created by Edd on 2026-07-17.
//

import SwiftUI

/// Two-card picker for quota-first vs pace-first display, each card led by
/// the question that mode answers, with a live menu bar preview as evidence.
struct DisplayModePicker: View {
    @Binding var isPaceFirst: Bool
    let iconStyle: IconStyle
    let isColored: Bool

    // Rasterizing an NSImage is comparatively expensive, so cache the two previews
    // and re-render only when the inputs that shape them change - not on every
    // unrelated settings re-render.
    @State private var consumptionPreview: NSImage?
    @State private var pacePreview: NSImage?

    var body: some View {
        HStack(spacing: 12) {
            DisplayModeCard(
                question: "How much have I used?",
                name: "Consumption",
                why: "Track what you've used of each limit",
                isSelected: !isPaceFirst,
                preview: consumptionPreview
            ) {
                isPaceFirst = false
            }

            DisplayModeCard(
                question: "Am I on track?",
                name: "Pace",
                why: "Max your plan: no lockouts, no unused quota",
                isSelected: isPaceFirst,
                preview: pacePreview
            ) {
                isPaceFirst = true
            }
        }
        .onAppear(perform: renderPreviews)
        .onChange(of: iconStyle) { renderPreviews() }
        .onChange(of: isColored) { renderPreviews() }
    }

    private func renderPreviews() {
        let renderer = MenuBarIconRenderer()
        consumptionPreview = renderPreview(renderer, paceRatio: nil, paceKind: nil)
        pacePreview = renderPreview(renderer, paceRatio: 1.8, paceKind: .hot)
    }

    private func renderPreview(_ renderer: MenuBarIconRenderer, paceRatio: Double?, paceKind: PaceKind?) -> NSImage {
        renderer.render(
            percentage: 65,
            status: .warning,
            isLoading: false,
            isStale: false,
            iconStyle: iconStyle,
            weeklyPercentage: 45,
            isColored: isColored,
            paceKind: paceKind,
            paceRatio: paceRatio
        )
    }
}

/// One display mode card: question headline, live preview, mode name, and why
struct DisplayModeCard: View {
    let question: String
    let name: String
    let why: String
    let isSelected: Bool
    let preview: NSImage?
    let onSelect: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text("\u{201C}\(question)\u{201D}")
                .font(.caption)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(NSColor.windowBackgroundColor))
                    .frame(height: 32)

                if let preview {
                    Image(nsImage: preview)
                        .scaleEffect(1.2)
                        .accessibilityHidden(true)
                }
            }

            HStack(spacing: 4) {
                Text(name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .accentColor : .primary)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.accentColor)
                }
            }

            Text(why)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name) display mode: \(question) \(why)")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var isPaceFirst = false

        var body: some View {
            DisplayModePicker(isPaceFirst: $isPaceFirst, iconStyle: .minimal, isColored: true)
                .padding()
                .frame(width: 400)
        }
    }

    return PreviewWrapper()
}
