//
//  CacheRepository.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-14.
//

import Foundation

/// Actor-isolated two-tier cache repository, scoped per account.
actor CacheRepository: CacheRepositoryProtocol {
    private struct MemoryEntry {
        let data: UsageData
        let timestamp: Date
    }

    private var memoryCache: [UUID: MemoryEntry] = [:]
    private let cacheTTL: TimeInterval = Constants.Cache.ttl
    private let cacheDir: URL
    private let publicJSONURL: URL
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let appSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        let cacheDir = appSupport.appendingPathComponent("com.claudemeter", isDirectory: true)
        try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        self.cacheDir = cacheDir

        // Public JSON export at ~/.claudemeter/usage.json for external tools
        let homeDir = fileManager.homeDirectoryForCurrentUser
        let publicDir = homeDir.appendingPathComponent(".claudemeter", isDirectory: true)
        try? fileManager.createDirectory(at: publicDir, withIntermediateDirectories: true)
        self.publicJSONURL = publicDir.appendingPathComponent("usage.json")
    }

    // MARK: - Public API

    func get(accountId: UUID) async -> UsageData? {
        if let entry = memoryCache[accountId],
           Date().timeIntervalSince(entry.timestamp) < cacheTTL {
            return entry.data
        }
        return nil
    }

    func set(_ data: UsageData, accountId: UUID, isPrimary: Bool) async {
        memoryCache[accountId] = MemoryEntry(data: data, timestamp: Date())
        await saveToDisk(data, accountId: accountId, isPrimary: isPrimary)
    }

    func invalidate(accountId: UUID) async {
        memoryCache[accountId] = nil
    }

    func getLastKnown(accountId: UUID) async -> UsageData? {
        loadFromDisk(accountId: accountId)
    }

    func purge(accountId: UUID) async {
        memoryCache[accountId] = nil
        try? fileManager.removeItem(at: diskURL(for: accountId))
    }

    // MARK: - Private

    private func diskURL(for accountId: UUID) -> URL {
        cacheDir.appendingPathComponent("usage_\(accountId.uuidString).json")
    }

    private func saveToDisk(_ data: UsageData, accountId: UUID, isPrimary: Bool) async {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        guard let jsonData = try? encoder.encode(data) else { return }

        try? jsonData.write(to: diskURL(for: accountId), options: .atomic)

        if isPrimary {
            saveToPublicJSON(data)
        }
    }

    private func saveToPublicJSON(_ data: UsageData) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let jsonData = try? encoder.encode(data) else { return }
        try? jsonData.write(to: publicJSONURL, options: .atomic)
    }

    private func loadFromDisk(accountId: UUID) -> UsageData? {
        guard let jsonData = try? Data(contentsOf: diskURL(for: accountId)) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try? decoder.decode(UsageData.self, from: jsonData)
    }
}
