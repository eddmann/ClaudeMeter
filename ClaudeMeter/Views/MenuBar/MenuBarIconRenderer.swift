//
//  MenuBarIconRenderer.swift
//  ClaudeMeter
//
//  Created by Edd on 2026-01-09.
//

import AppKit
import SwiftUI

/// Renders SwiftUI MenuBarIconView to NSImage using ImageRenderer.
@MainActor
struct MenuBarIconRenderer {
    func render(
        percentage: Double,
        status: UsageStatus,
        isLoading: Bool,
        isStale: Bool,
        iconStyle: IconStyle,
        weeklyPercentage: Double = 0,
        useColor: Bool = true
    ) -> NSImage {
        let iconView = MenuBarIconView(
            percentage: percentage,
            status: status,
            isLoading: isLoading,
            isStale: isStale,
            iconStyle: iconStyle,
            weeklyPercentage: weeklyPercentage,
            useColor: useColor
        )

        let renderer = ImageRenderer(content: iconView)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0

        guard let nsImage = renderer.nsImage else {
            return NSImage(
                systemSymbolName: "exclamationmark.triangle",
                accessibilityDescription: "Error"
            ) ?? NSImage()
        }

        // In monochrome mode the menu bar handles tinting (white on dark menu bars, black on
        // light) via template rendering. In colour mode the original status palette is preserved.
        nsImage.isTemplate = !useColor
        return nsImage
    }
}
