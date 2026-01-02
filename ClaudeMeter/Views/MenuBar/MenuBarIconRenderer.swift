//
//  MenuBarIconRenderer.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-14.
//

import AppKit
import SwiftUI

/// Renders SwiftUI MenuBarIconView to NSImage using ImageRenderer
@MainActor
struct MenuBarIconRenderer {
    /// Render menu bar icon to NSImage
    func render(percentage: Double, status: UsageStatus, isLoading: Bool, isStale: Bool, iconStyle: IconStyle, weeklyPercentage: Double = 0) -> NSImage {
        let iconView = MenuBarIconView(
            percentage: percentage,
            status: status,
            isLoading: isLoading,
            isStale: isStale,
            iconStyle: iconStyle,
            weeklyPercentage: weeklyPercentage
        )

        let renderer = ImageRenderer(content: iconView)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0

        guard let nsImage = renderer.nsImage else {
            // Fallback to system icon if rendering fails
            return NSImage(
                systemSymbolName: "exclamationmark.triangle",
                accessibilityDescription: "Error"
            ) ?? NSImage()
        }

        nsImage.isTemplate = false // Use colored icons for status indication
        return nsImage
    }
}
