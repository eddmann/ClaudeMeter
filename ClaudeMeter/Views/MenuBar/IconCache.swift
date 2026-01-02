//
//  IconCache.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-14.
//

import AppKit

/// Cache for rendered menu bar icons using NSCache for automatic LRU eviction
@MainActor
final class IconCache {
    private let cache = NSCache<CacheKeyWrapper, NSImage>()

    init() {
        cache.countLimit = Constants.Cache.maxIconCacheSize
    }

    final class CacheKeyWrapper: NSObject {
        let key: CacheKey

        init(_ key: CacheKey) {
            self.key = key
        }

        override var hash: Int {
            key.hashValue
        }

        override func isEqual(_ object: Any?) -> Bool {
            guard let other = object as? CacheKeyWrapper else { return false }
            return key == other.key
        }
    }

    struct CacheKey: Hashable {
        let percentage: Int
        let status: UsageStatus
        let isLoading: Bool
        let isStale: Bool
        let iconStyle: IconStyle
        let weeklyPercentage: Int
    }

    /// Get cached icon if available
    func get(percentage: Double, status: UsageStatus, isLoading: Bool, isStale: Bool, iconStyle: IconStyle, weeklyPercentage: Double = 0) -> NSImage? {
        let key = CacheKey(
            percentage: Int(percentage),
            status: status,
            isLoading: isLoading,
            isStale: isStale,
            iconStyle: iconStyle,
            weeklyPercentage: Int(weeklyPercentage)
        )
        return cache.object(forKey: CacheKeyWrapper(key))
    }

    /// Store rendered icon in cache
    func set(_ image: NSImage, percentage: Double, status: UsageStatus, isLoading: Bool, isStale: Bool, iconStyle: IconStyle, weeklyPercentage: Double = 0) {
        let key = CacheKey(
            percentage: Int(percentage),
            status: status,
            isLoading: isLoading,
            isStale: isStale,
            iconStyle: iconStyle,
            weeklyPercentage: Int(weeklyPercentage)
        )

        cache.setObject(image, forKey: CacheKeyWrapper(key))
    }

    /// Clear all cached icons
    func clear() {
        cache.removeAllObjects()
    }
}
