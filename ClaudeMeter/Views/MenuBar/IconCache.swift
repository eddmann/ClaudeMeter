//
//  IconCache.swift
//  ClaudeMeter
//
//  Created by Edd on 2026-01-09.
//

import AppKit

/// Simple in-memory cache for rendered menu bar icons.
final class IconCache {
    private let cache = NSCache<NSString, NSImage>()

    init() {
        cache.countLimit = Constants.Cache.maxIconCacheSize
    }

    func get(
        percentage: Double,
        status: UsageStatus,
        isLoading: Bool,
        isStale: Bool,
        iconStyle: IconStyle,
        weeklyPercentage: Double,
        hasSessionLimit: Bool = true,
        isColored: Bool
    ) -> NSImage? {
        cache.object(forKey: cacheKey(
            percentage: percentage,
            status: status,
            isLoading: isLoading,
            isStale: isStale,
            iconStyle: iconStyle,
            weeklyPercentage: weeklyPercentage,
            hasSessionLimit: hasSessionLimit,
            isColored: isColored
        ))
    }

    func set(
        _ image: NSImage,
        percentage: Double,
        status: UsageStatus,
        isLoading: Bool,
        isStale: Bool,
        iconStyle: IconStyle,
        weeklyPercentage: Double,
        hasSessionLimit: Bool = true,
        isColored: Bool
    ) {
        cache.setObject(
            image,
            forKey: cacheKey(
                percentage: percentage,
                status: status,
                isLoading: isLoading,
                isStale: isStale,
                iconStyle: iconStyle,
                weeklyPercentage: weeklyPercentage,
                hasSessionLimit: hasSessionLimit,
                isColored: isColored
            )
        )
    }

    private func cacheKey(
        percentage: Double,
        status: UsageStatus,
        isLoading: Bool,
        isStale: Bool,
        iconStyle: IconStyle,
        weeklyPercentage: Double,
        hasSessionLimit: Bool,
        isColored: Bool
    ) -> NSString {
        let percent = String(format: "%.2f", percentage)
        let weekly = String(format: "%.2f", weeklyPercentage)
        return "\(percent)|\(weekly)|\(status.rawValue)|\(isLoading)|\(isStale)|\(iconStyle.rawValue)|\(hasSessionLimit)|\(isColored)" as NSString
    }
}
