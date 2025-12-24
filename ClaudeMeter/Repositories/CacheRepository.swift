//
//  CacheRepository.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-14.
//

import Foundation

/// Actor-isolated two-tier cache repository
actor CacheRepository: CacheRepositoryProtocol {
    private var memoryCache: UsageData?
    private var memoryCacheTimestamp: Date?
    private let cacheTTL: TimeInterval = Constants.Cache.ttl
    private let diskCacheURL: URL
    private let publicJSONURL: URL

    init(fileManager: FileManager = .default) {
        let appSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        let cacheDir = appSupport.appendingPathComponent("com.claudemeter", isDirectory: true)
        try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        self.diskCacheURL = cacheDir.appendingPathComponent("usage_cache.json")

        // Public JSON export at ~/.claudemeter/usage.json for external tools
        let homeDir = fileManager.homeDirectoryForCurrentUser
        let publicDir = homeDir.appendingPathComponent(".claudemeter", isDirectory: true)
        try? fileManager.createDirectory(at: publicDir, withIntermediateDirectories: true)
        self.publicJSONURL = publicDir.appendingPathComponent("usage.json")
    }

    /// Get cached usage data (respects TTL)
    func get() async -> UsageData? {
        // Check in-memory cache first
        if let cached = memoryCache,
           let timestamp = memoryCacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheTTL {
            return cached
        }

        // Memory cache is stale or missing
        return nil
    }

    /// Cache usage data in both memory and disk
    func set(_ data: UsageData) async {
        memoryCache = data
        memoryCacheTimestamp = Date()
        await saveToDisk(data)
    }

    /// Invalidate memory cache
    func invalidate() async {
        memoryCache = nil
        memoryCacheTimestamp = nil
    }

    /// Get last known data from disk (ignores TTL) for offline display
    func getLastKnown() async -> UsageData? {
        await loadFromDisk()
    }

    // MARK: - Private Methods

    private func saveToDisk(_ data: UsageData) async {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        guard let jsonData = try? encoder.encode(data) else {
            return
        }

        do {
            try jsonData.write(to: diskCacheURL, options: .atomic)
        } catch {
            // Silently fail
        }

        // Also write to public location for external tools (statusline scripts, etc.)
        saveToPublicJSON(data)
    }

    private func saveToPublicJSON(_ data: UsageData) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let jsonData = try? encoder.encode(data) else {
            return
        }

        do {
            try jsonData.write(to: publicJSONURL, options: .atomic)
        } catch {
            // Silently fail - external tools location is optional
        }
    }

    private func loadFromDisk() async -> UsageData? {
        guard let jsonData = try? Data(contentsOf: diskCacheURL) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(UsageData.self, from: jsonData)
        } catch {
            return nil
        }
    }
}
