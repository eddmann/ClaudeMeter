//
//  SettingsRepository.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-14.
//

import Foundation

/// Actor-isolated repository for app settings persistence using UserDefaults
actor SettingsRepository: SettingsRepositoryProtocol {
    private let userDefaults: UserDefaults
    private let settingsKey = "app_settings"
    private let notificationStateKey = "notification_state"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    /// Load app settings from UserDefaults
    func load() async -> AppSettings {
        guard let data = userDefaults.data(forKey: settingsKey) else {
            return .default
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(AppSettings.self, from: data)
        } catch {
            // If decoding fails, return default settings
            return .default
        }
    }

    /// Save app settings to UserDefaults
    func save(_ settings: AppSettings) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(settings)
        userDefaults.set(data, forKey: settingsKey)
    }

    /// Load notification state from UserDefaults
    func loadNotificationState() async -> NotificationState {
        guard let data = userDefaults.data(forKey: notificationStateKey) else {
            return NotificationState()
        }

        let decoder = JSONDecoder()

        do {
            return try decoder.decode(NotificationState.self, from: data)
        } catch {
            return NotificationState()
        }
    }

    /// Save notification state to UserDefaults
    func saveNotificationState(_ state: NotificationState) async throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(state)
        userDefaults.set(data, forKey: notificationStateKey)
    }
}
