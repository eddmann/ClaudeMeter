//
//  MenuBarLabelView.swift
//  ClaudeMeter
//
//  Created by Edd on 2026-01-09.
//

import SwiftUI
import AppKit

struct MenuBarLabelView: View {
    @Bindable var appModel: AppModel
    @State private var iconCache = IconCache()
    private let renderer = MenuBarIconRenderer()

    var body: some View {
        let status = appModel.usageData?.primaryStatus ?? .safe
        let isLoading = appModel.isLoading
        let isStale = appModel.usageData?.isStale ?? false
        let style = appModel.settings.iconStyle
        let weekly = weeklyPercentage
        let percentage = sessionPercentage

        let image = iconCache.get(
            percentage: percentage,
            status: status,
            isLoading: isLoading,
            isStale: isStale,
            iconStyle: style,
            weeklyPercentage: weekly
        ) ?? {
            let rendered = renderer.render(
                percentage: percentage,
                status: status,
                isLoading: isLoading,
                isStale: isStale,
                iconStyle: style,
                weeklyPercentage: weekly
            )
            iconCache.set(
                rendered,
                percentage: percentage,
                status: status,
                isLoading: isLoading,
                isStale: isStale,
                iconStyle: style,
                weeklyPercentage: weekly
            )
            return rendered
        }()

        Image(nsImage: image)
            .renderingMode(.original)
            .accessibilityLabel("ClaudeMeter")
    }

    private var sessionPercentage: Double {
        let value = appModel.usageData?.sessionUsage.percentage ?? 0
        return max(0, min(value, 100))
    }

    private var weeklyPercentage: Double {
        let value = appModel.usageData?.weeklyUsage.percentage ?? 0
        return max(0, min(value, 100))
    }
}
