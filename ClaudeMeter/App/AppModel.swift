//
//  AppModel.swift
//  ClaudeMeter
//
//  Created by Edd on 2026-01-09.
//

import AppKit
import Foundation
import Observation

/// Per-account fetch state. Stored in dictionaries keyed by account id on AppModel.
struct AccountUsageState: Equatable, Sendable {
    var usageData: UsageData?
    var isLoading: Bool = false
    var isRefreshing: Bool = false
    var errorMessage: String?
}

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

    /// Per-account usage state. Read via `state(for:)`.
    var accountStates: [UUID: AccountUsageState] = [:]
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

    /// Account name used by the legacy single-account schema (pre multi-account migration).
    @ObservationIgnored private let legacyKeychainAccount = "default"

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
            keychainRepository: keychainRepository
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

        await migrateLegacyKeychainIfNeeded()

        isReady = true

        if !settings.accounts.isEmpty {
            await refreshAllUsage(forceRefresh: true)
            startRefreshLoop()
        }

        startWakeObserver()
    }

    /// Convenience: returns whether any account is configured.
    var isSetupComplete: Bool { !settings.accounts.isEmpty }

    func state(for accountId: UUID) -> AccountUsageState {
        accountStates[accountId] ?? AccountUsageState()
    }

    // MARK: - Usage

    /// Refresh a single account.
    func refreshUsage(accountId: UUID, forceRefresh: Bool = false) async {
        guard let account = settings.account(withId: accountId) else {
            accountStates[accountId] = nil
            return
        }

        var state = state(for: accountId)
        guard !state.isRefreshing else { return }

        if state.usageData == nil {
            state.isLoading = true
        }
        state.isRefreshing = true
        state.errorMessage = nil
        accountStates[accountId] = state

        defer {
            var s = self.state(for: accountId)
            s.isLoading = false
            s.isRefreshing = false
            self.accountStates[accountId] = s
        }

        do {
            let isPrimary = settings.accounts.first?.id == accountId
            let data = try await usageService.fetchUsage(
                for: account,
                isPrimary: isPrimary,
                forceRefresh: forceRefresh
            )
            var done = self.state(for: accountId)
            done.usageData = data
            self.accountStates[accountId] = done

            await notificationService.evaluateThresholds(
                usageData: data,
                settings: settings
            )
        } catch {
            var failed = self.state(for: accountId)
            failed.errorMessage = error.localizedDescription
            self.accountStates[accountId] = failed
        }
    }

    /// Refresh every configured account in parallel.
    func refreshAllUsage(forceRefresh: Bool = false) async {
        let accountIds = settings.accounts.map(\.id)
        await withTaskGroup(of: Void.self) { group in
            for id in accountIds {
                group.addTask { @MainActor in
                    await self.refreshUsage(accountId: id, forceRefresh: forceRefresh)
                }
            }
        }
    }

    // MARK: - Account Management

    /// Look up the session key for an account from the keychain.
    func loadSessionKey(accountId: UUID) async -> String? {
        guard let account = settings.account(withId: accountId) else { return nil }
        do {
            return try await keychainRepository.retrieve(account: account.keychainAccount)
        } catch {
            return nil
        }
    }

    /// Validate a session key, look up its organization, and create a new account.
    /// - Returns: the freshly added account on success, or `nil` if validation failed.
    @discardableResult
    func addAccount(label: String, sessionKey rawValue: String) async throws -> ClaudeAccount? {
        let sessionKey = try SessionKey(rawValue)
        let isValid = try await usageService.validateSessionKey(sessionKey)
        guard isValid else { return nil }

        let organizations = try await usageService.fetchOrganizations(sessionKey: sessionKey)
        guard let firstOrg = organizations.first,
              let orgUUID = firstOrg.organizationUUID else {
            throw AppError.organizationNotFound
        }

        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedLabel = trimmed.isEmpty ? defaultLabelForNewAccount() : trimmed

        let account = ClaudeAccount(label: resolvedLabel, organizationId: orgUUID)
        try await keychainRepository.save(sessionKey: sessionKey.value, account: account.keychainAccount)

        settings.accounts.append(account)
        settings.isFirstLaunch = false

        await refreshUsage(accountId: account.id, forceRefresh: true)
        startRefreshLoop()

        return account
    }

    /// Replace the session key for an existing account (without changing its id/label).
    @discardableResult
    func updateSessionKey(accountId: UUID, _ rawValue: String) async throws -> Bool {
        guard let index = settings.accounts.firstIndex(where: { $0.id == accountId }) else {
            return false
        }
        let sessionKey = try SessionKey(rawValue)
        let isValid = try await usageService.validateSessionKey(sessionKey)
        guard isValid else { return false }

        let organizations = try await usageService.fetchOrganizations(sessionKey: sessionKey)
        guard let firstOrg = organizations.first,
              let orgUUID = firstOrg.organizationUUID else {
            throw AppError.organizationNotFound
        }

        try await keychainRepository.save(
            sessionKey: sessionKey.value,
            account: settings.accounts[index].keychainAccount
        )
        settings.accounts[index].organizationId = orgUUID
        await refreshUsage(accountId: accountId, forceRefresh: true)
        return true
    }

    /// Rename an account.
    func renameAccount(_ accountId: UUID, label: String) {
        guard let index = settings.accounts.firstIndex(where: { $0.id == accountId }) else { return }
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        settings.accounts[index].label = trimmed
    }

    /// Remove an account: deletes its session key and any cached state.
    func removeAccount(_ accountId: UUID) async throws {
        guard let account = settings.account(withId: accountId) else { return }
        try? await keychainRepository.delete(account: account.keychainAccount)
        settings.accounts.removeAll(where: { $0.id == accountId })
        accountStates[accountId] = nil
        if settings.accounts.isEmpty {
            settings.isFirstLaunch = true
            refreshTask?.cancel()
        }
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

    /// One-time migration from the pre-multi-account schema: when settings still hold a single
    /// "Default" account synthesised from the legacy `cached_organization_id`, copy the keychain
    /// session key from the legacy "default" slot to the new per-account UUID slot.
    private func migrateLegacyKeychainIfNeeded() async {
        guard await keychainRepository.exists(account: legacyKeychainAccount) else { return }
        guard let firstAccount = settings.accounts.first else { return }
        // Already migrated if the new slot has a key.
        if await keychainRepository.exists(account: firstAccount.keychainAccount) { return }

        do {
            let key = try await keychainRepository.retrieve(account: legacyKeychainAccount)
            try await keychainRepository.save(sessionKey: key, account: firstAccount.keychainAccount)
            try await keychainRepository.delete(account: legacyKeychainAccount)
        } catch {
            // If the legacy slot can't be read, leave it alone — the user will be prompted to re-enter.
        }
    }

    private func defaultLabelForNewAccount() -> String {
        let n = settings.accounts.count + 1
        return "Account \(n)"
    }

    private func scheduleSettingsSave(previous: AppSettings) {
        settingsSaveTask?.cancel()
        let snapshot = settings
        settingsSaveTask = Task { [settingsRepository] in
            try? await settingsRepository.save(snapshot)
        }

        if previous.refreshInterval != settings.refreshInterval {
            startRefreshLoop()
        }
    }

    private func startRefreshLoop() {
        refreshTask?.cancel()
        guard !settings.accounts.isEmpty else { return }

        let interval = Duration.seconds(Int(settings.refreshInterval))
        refreshTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await self.refreshClock.sleep(for: interval)
                await self.refreshAllUsage()
            }
        }
    }

    private func startWakeObserver() {
        wakeTask?.cancel()
        wakeTask = Task { [weak self] in
            guard let self else { return }
            for await _ in NSWorkspace.shared.notificationCenter.notifications(named: NSWorkspace.didWakeNotification) {
                await self.refreshAllUsage(forceRefresh: true)
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
        if isSetupComplete {
            let demoAccount = ClaudeAccount(label: "Demo")
            settings.accounts = [demoAccount]
            var state = AccountUsageState()
            state.usageData = usageData
            state.errorMessage = errorMessage
            state.isLoading = isLoading
            accountStates[demoAccount.id] = state
        } else {
            settings.accounts = []
            accountStates = [:]
        }
        self.isReady = true
        self.hasLoadedSettings = true
        // Don't start refresh loop or wake observer in demo mode
    }
    #endif
}
