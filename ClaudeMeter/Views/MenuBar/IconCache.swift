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
        isColored: Bool,
        paceKind: PaceKind?,
        paceRatio: Double?
    ) -> NSImage? {
        cache.object(forKey: cacheKey(
            percentage: percentage,
            status: status,
            isLoading: isLoading,
            isStale: isStale,
            iconStyle: iconStyle,
            weeklyPercentage: weeklyPercentage,
            isColored: isColored,
            paceKind: paceKind,
            paceRatio: paceRatio
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
        isColored: Bool,
        paceKind: PaceKind?,
        paceRatio: Double?
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
                isColored: isColored,
                paceKind: paceKind,
                paceRatio: paceRatio
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
        isColored: Bool,
        paceKind: PaceKind?,
        paceRatio: Double?
    ) -> NSString {
        let percent = String(format: "%.2f", percentage)
        let weekly = String(format: "%.2f", weeklyPercentage)
        let pace = paceKind?.rawValue ?? "none"
        // The displayed ratio is rounded to 1 decimal, but its rendered color is a
        // function of the full-precision value. Two ratios that round equal can
        // straddle a PacePalette threshold (e.g. 2.49 vs 2.53 -> orange vs red), so
        // the color band must be part of the key or they'd collide on a stale image.
        let ratio = paceRatio.map { String(format: "%.1f", $0) } ?? "none"
        let band = paceRatio.map { PacePalette.band(for: $0).rawValue } ?? "none"
        return "\(percent)|\(weekly)|\(status.rawValue)|\(isLoading)|\(isStale)|\(iconStyle.rawValue)|\(isColored)|\(pace)|\(ratio)|\(band)" as NSString
    }
}
