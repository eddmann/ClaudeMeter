//
//  MenuBarViewModel.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-14.
//

import Foundation
import Combine
import AppKit

/// ViewModel for menu bar icon and automatic refresh
@MainActor
final class MenuBarViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var usageData: UsageData?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let usageService: UsageServiceProtocol
    private let settingsRepository: SettingsRepositoryProtocol
    private let notificationService: NotificationServiceProtocol

    // MARK: - Private Properties

    private var refreshTimer: Timer?
    private var refreshInterval: TimeInterval = 60
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        usageService: UsageServiceProtocol,
        settingsRepository: SettingsRepositoryProtocol,
        notificationService: NotificationServiceProtocol
    ) {
        self.usageService = usageService
        self.settingsRepository = settingsRepository
        self.notificationService = notificationService

        setupRefreshTimer()
        setupSettingsObserver()
        setupWakeFromSleepObserver()

        // Show loading state immediately and force refresh on boot
        isLoading = true
        Task {
            await fetchUsage(forceRefresh: true)
        }
    }

    deinit {
        refreshTimer?.invalidate()
    }

    // MARK: - Public Methods

    /// Fetch usage data
    func fetchUsage(forceRefresh: Bool = false) async {
        if usageData == nil {
            isLoading = true
        }
        errorMessage = nil

        do {
            let data = try await usageService.fetchUsage(forceRefresh: forceRefresh)
            self.usageData = data
            isLoading = false

            // Check for threshold notifications
            await checkThresholds(data: data)

        } catch {
            // Handle errors with retry logic
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Private Methods

    /// Setup automatic refresh timer
    private func setupRefreshTimer() {
        Task {
            let settings = await settingsRepository.load()
            refreshInterval = settings.refreshInterval

            refreshTimer = Timer.scheduledTimer(
                withTimeInterval: refreshInterval,
                repeats: true
            ) { [weak self] _ in
                Task { @MainActor in
                    await self?.fetchUsage()
                }
            }
        }
    }

    /// Setup settings change observer
    private func setupSettingsObserver() {
        NotificationCenter.default.publisher(for: .settingsDidChange)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.handleSettingsChanged()
                }
            }
            .store(in: &cancellables)
    }

    /// Setup wake from sleep observer
    private func setupWakeFromSleepObserver() {
        NSWorkspace.shared.notificationCenter.publisher(
            for: NSWorkspace.didWakeNotification
        )
        .sink { [weak self] _ in
            Task { @MainActor in
                await self?.fetchUsage()
            }
        }
        .store(in: &cancellables)
    }

    /// Handle settings changes
    private func handleSettingsChanged() async {
        let settings = await settingsRepository.load()

        if settings.refreshInterval != refreshInterval {
            refreshInterval = settings.refreshInterval
            refreshTimer?.invalidate()
            setupRefreshTimer()
        }
    }

    /// Check usage thresholds and send notifications
    private func checkThresholds(data: UsageData) async {
        let percentage = data.sessionUsage.percentage

        // Load current threshold settings
        let settings = await settingsRepository.load()
        let warningThreshold = settings.notificationThresholds.warningThreshold
        let criticalThreshold = settings.notificationThresholds.criticalThreshold

        // Check warning threshold
        if percentage >= warningThreshold && percentage < criticalThreshold {
            try? await notificationService.sendThresholdNotification(
                percentage: percentage,
                threshold: .warning,
                resetTime: data.sessionUsage.resetAt
            )
        }

        // Check critical threshold
        if percentage >= criticalThreshold {
            try? await notificationService.sendThresholdNotification(
                percentage: percentage,
                threshold: .critical,
                resetTime: data.sessionUsage.resetAt
            )
        }

        // Check for session reset
        let state = await settingsRepository.loadNotificationState()
        if state.shouldNotifyReset(currentPercentage: percentage) {
            try? await notificationService.sendResetNotification()
        }

        // Reset threshold tracking if usage dropped
        if percentage < warningThreshold {
            await notificationService.resetThresholdTracking(for: .warning)
        }
        if percentage < criticalThreshold {
            await notificationService.resetThresholdTracking(for: .critical)
        }
    }
}
