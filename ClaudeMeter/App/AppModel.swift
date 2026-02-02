//
//  AppModel.swift
//  ClaudeMeter
//
//  Created by Edd on 2026-01-09.
//

import AppKit
import Foundation
import Observation

/// Main application model for SwiftUI-first architecture.
@MainActor
@Observable
final class AppModel {
    // MARK: - Published State

    var settings: AppSettings = .default {
        didSet {
            guard hasLoadedSettings else { return }
            scheduleSettingsSave(previous: oldValue)
        }
    }

    var usageData: UsageData?
    var isLoading: Bool = false
    var isRefreshing: Bool = false
    var errorMessage: String?
    var isSetupComplete: Bool = false
    var isReady: Bool = false

    // MARK: - Dependencies

    @ObservationIgnored private let settingsRepository: SettingsRepositoryProtocol
    @ObservationIgnored private let keychainRepository: KeychainRepositoryProtocol
    @ObservationIgnored private let usageService: UsageServiceProtocol
    @ObservationIgnored private let notificationService: NotificationServiceProtocol

    // MARK: - Private

    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var settingsSaveTask: Task<Void, Never>?
    @ObservationIgnored private var wakeTask: Task<Void, Never>?
    @ObservationIgnored private var hasLoadedSettings: Bool = false
    @ObservationIgnored private let refreshClock = ContinuousClock()

    // MARK: - Initialization

    init(
        settingsRepository: SettingsRepositoryProtocol = SettingsRepository(),
        keychainRepository: KeychainRepositoryProtocol = KeychainRepository(),
        usageService: UsageServiceProtocol? = nil,
        notificationService: NotificationServiceProtocol? = nil
    ) {
        self.settingsRepository = settingsRepository
        self.keychainRepository = keychainRepository

        let networkService = NetworkService()
        let cacheRepository = CacheRepository()
        let usageService = usageService ?? UsageService(
            networkService: networkService,
            cacheRepository: cacheRepository,
            keychainRepository: keychainRepository,
            settingsRepository: settingsRepository
        )
        self.usageService = usageService
        self.notificationService = notificationService ?? NotificationService(
            settingsRepository: settingsRepository
        )

        self.notificationService.setupDelegate()
    }

    // MARK: - Lifecycle

    func bootstrap() async {
        guard !isReady else { return }
        settings = await settingsRepository.load()
        hasLoadedSettings = true

        isSetupComplete = await keychainRepository.exists(account: "default")
        isReady = true

        if isSetupComplete {
            await refreshUsage(forceRefresh: true)
            startRefreshLoop()
        }

        startWakeObserver()
    }

    // MARK: - Usage

    func refreshUsage(forceRefresh: Bool = false) async {
        guard isSetupComplete else {
            usageData = nil
            return
        }
        guard !isRefreshing else { return }

        if usageData == nil {
            isLoading = true
        }
        isRefreshing = true
        errorMessage = nil

        defer {
            isLoading = false
            isRefreshing = false
        }

        do {
            let data = try await usageService.fetchUsage(forceRefresh: forceRefresh)
            usageData = data
            await notificationService.evaluateThresholds(
                usageData: data,
                settings: settings
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Session Key

    func loadSessionKey() async -> String? {
        do {
            return try await keychainRepository.retrieve(account: "default")
        } catch KeychainError.notFound {
            return nil
        } catch {
            return nil
        }
    }

    func validateAndSaveSessionKey(_ rawValue: String) async throws -> Bool {
        let sessionKey = try SessionKey(rawValue)
        let isValid = try await usageService.validateSessionKey(sessionKey)

        guard isValid else {
            return false
        }

        let organizations = try await usageService.fetchOrganizations(sessionKey: sessionKey)
        guard let firstOrg = organizations.first,
              let orgUUID = firstOrg.organizationUUID else {
            throw AppError.organizationNotFound
        }

        try await keychainRepository.save(sessionKey: sessionKey.value, account: "default")

        settings.cachedOrganizationId = orgUUID
        settings.isFirstLaunch = false
        isSetupComplete = true

        await refreshUsage(forceRefresh: true)
        startRefreshLoop()

        return true
    }

    func clearSessionKey() async throws {
        try await keychainRepository.delete(account: "default")
        settings.cachedOrganizationId = nil
        settings.isFirstLaunch = true
        isSetupComplete = false
        usageData = nil
        errorMessage = nil
        refreshTask?.cancel()
    }

    // MARK: - Notifications

    func requestNotificationPermissionIfNeeded() async {
        let hasPermission = await notificationService.checkNotificationPermissions()
        if !hasPermission {
            _ = try? await notificationService.requestAuthorization()
        }
    }

    func checkNotificationPermissions() async -> Bool {
        await notificationService.checkNotificationPermissions()
    }

    func sendTestNotification() async throws {
        try await notificationService.sendThresholdNotification(
            percentage: 85.0,
            threshold: .warning,
            resetTime: Date().addingTimeInterval(3600)
        )
    }

    // MARK: - Private

    private func scheduleSettingsSave(previous: AppSettings) {
        settingsSaveTask?.cancel()
        settingsSaveTask = Task {
            try? await settingsRepository.save(settings)
        }

        if previous.refreshInterval != settings.refreshInterval {
            startRefreshLoop()
        }
    }

    private func startRefreshLoop() {
        refreshTask?.cancel()
        guard isSetupComplete else { return }

        let interval = Duration.seconds(Int(settings.refreshInterval))
        refreshTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await self.refreshClock.sleep(for: interval)
                await self.refreshUsage()
            }
        }
    }

    private func startWakeObserver() {
        wakeTask?.cancel()
        wakeTask = Task { [weak self] in
            guard let self else { return }
            for await _ in NSWorkspace.shared.notificationCenter.notifications(named: NSWorkspace.didWakeNotification) {
                await self.refreshUsage(forceRefresh: true)
            }
        }
    }

    // MARK: - Demo Mode

    #if DEBUG
    /// Applies demo state for App Store screenshots.
    /// Skips normal bootstrap and sets state directly.
    func applyDemoState(
        usageData: UsageData?,
        isSetupComplete: Bool,
        errorMessage: String?,
        isLoading: Bool
    ) {
        self.usageData = usageData
        self.isSetupComplete = isSetupComplete
        self.errorMessage = errorMessage
        self.isLoading = isLoading
        self.isReady = true
        self.hasLoadedSettings = true
        // Don't start refresh loop or wake observer in demo mode
    }
    #endif

}
