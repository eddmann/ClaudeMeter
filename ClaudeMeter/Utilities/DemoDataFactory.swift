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

        case .withSonnet:
            appModel.applyDemoState(
                usageData: makeUsageData(
                    sessionPercentage: 65,
                    weeklyPercentage: 40,
                    sonnetPercentage: 25
                ),
                isSetupComplete: true,
                errorMessage: nil,
                isLoading: false
            )
            appModel.settings.isSonnetUsageShown = true

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
        sonnetPercentage: Double? = nil
    ) -> UsageData {
        let sessionResetAt = Date().addingTimeInterval(3 * 3600) // 3 hours from now
        let weeklyResetAt = Date().addingTimeInterval(4 * 24 * 3600) // 4 days from now

        let sessionUsage = UsageLimit(utilization: sessionPercentage, resetAt: sessionResetAt)
        let weeklyUsage = UsageLimit(utilization: weeklyPercentage, resetAt: weeklyResetAt)

        let sonnetUsage: UsageLimit?
        if let sonnetPercentage {
            sonnetUsage = UsageLimit(utilization: sonnetPercentage, resetAt: weeklyResetAt)
        } else {
            sonnetUsage = nil
        }

        return UsageData(
            sessionUsage: sessionUsage,
            weeklyUsage: weeklyUsage,
            sonnetUsage: sonnetUsage,
            lastUpdated: Date()
        )
    }
}
#endif
