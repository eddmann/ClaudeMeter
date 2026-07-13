//
//  DemoDataFactory.swift
//  ClaudeMeter
//
//  Created by Edd on 2026-02-02.
//

#if DEBUG
import Foundation

/// Factory for creating demo state for App Store screenshots.
@MainActor
enum DemoDataFactory {
    /// Configures the app model for the given demo mode.
    static func configure(_ appModel: AppModel, for mode: DemoMode) {
        switch mode {
        case .safeUsage:
            appModel.applyDemoState(
                usageData: makeUsageData(sessionPercentage: 42, weeklyPercentage: 10),
                isSetupComplete: true,
                errorMessage: nil,
                isLoading: false
            )

        case .warningUsage:
            appModel.applyDemoState(
                usageData: makeUsageData(sessionPercentage: 72, weeklyPercentage: 45),
                isSetupComplete: true,
                errorMessage: nil,
                isLoading: false
            )

        case .criticalUsage:
            appModel.applyDemoState(
                usageData: makeUsageData(sessionPercentage: 92, weeklyPercentage: 85),
                isSetupComplete: true,
                errorMessage: nil,
                isLoading: false
            )

        case .exceededUsage:
            appModel.applyDemoState(
                usageData: makeUsageData(sessionPercentage: 105, weeklyPercentage: 100),
                isSetupComplete: true,
                errorMessage: nil,
                isLoading: false
            )

        case .withModelLimits:
            appModel.applyDemoState(
                usageData: makeUsageData(
                    sessionPercentage: 65,
                    weeklyPercentage: 40,
                    scopedPercentages: [("Fable", 23), ("Opus", 58)]
                ),
                isSetupComplete: true,
                errorMessage: nil,
                isLoading: false
            )
            appModel.settings.shownScopedModels = ["Fable", "Opus"]

        case .loading:
            appModel.applyDemoState(
                usageData: nil,
                isSetupComplete: true,
                errorMessage: nil,
                isLoading: true
            )

        case .error:
            appModel.applyDemoState(
                usageData: makeUsageData(sessionPercentage: 55, weeklyPercentage: 30),
                isSetupComplete: true,
                errorMessage: "Unable to connect to Claude.ai. Check your internet connection.",
                isLoading: false
            )

        case .setupWizard:
            appModel.applyDemoState(
                usageData: nil,
                isSetupComplete: false,
                errorMessage: nil,
                isLoading: false
            )
        }
    }

    /// Creates UsageData with the given percentages.
    private static func makeUsageData(
        sessionPercentage: Double,
        weeklyPercentage: Double,
        scopedPercentages: [(name: String, percentage: Double)] = []
    ) -> UsageData {
        let sessionResetAt = Date().addingTimeInterval(3 * 3600) // 3 hours from now
        let weeklyResetAt = Date().addingTimeInterval(4 * 24 * 3600) // 4 days from now

        return UsageData(
            sessionUsage: UsageLimit(utilization: sessionPercentage, resetAt: sessionResetAt),
            weeklyUsage: UsageLimit(utilization: weeklyPercentage, resetAt: weeklyResetAt),
            scopedUsage: scopedPercentages.enumerated().map { index, scoped in
                ScopedUsageLimit(
                    name: scoped.name,
                    limit: UsageLimit(utilization: scoped.percentage, resetAt: weeklyResetAt),
                    isActive: index == 0
                )
            },
            lastUpdated: Date()
        )
    }
}
#endif
