//
//  Constants.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-17.
//

import Foundation

/// Application-wide constants
enum Constants {
    /// Cache configuration
    enum Cache {
        /// Memory cache time-to-live (slightly less than minimum refresh interval)
        static let ttl: TimeInterval = 55

        /// Maximum number of cached icons
        static let maxIconCacheSize = 100
    }

    /// Network configuration
    enum Network {
        /// Maximum number of retry attempts for failed requests
        static let maxRetries = 3

        /// Base delay multiplier for exponential backoff (network errors)
        static let backoffBase: Double = 2.0

        /// Base delay multiplier for rate limit backoff (more aggressive)
        static let rateLimitBackoffBase: Double = 3.0
    }

    /// Refresh intervals (in seconds)
    enum Refresh {
        /// Minimum refresh interval
        static let minimum: TimeInterval = 60

        /// Maximum refresh interval
        static let maximum: TimeInterval = 600

        /// Staleness threshold (2x max refresh interval to account for retries/delays)
        static let stalenessThreshold: TimeInterval = 1200
    }

    /// Pacing/risk calculation configuration
    enum Pacing {
        /// 5-hour session window duration
        static let sessionWindow: TimeInterval = 5 * 60 * 60

        /// 7-day weekly window duration
        static let weeklyWindow: TimeInterval = 7 * 24 * 60 * 60

        /// Ratio threshold for "at risk"/overuse status: any burn above the
        /// sustainable line (1.0 = on track to reach the limit exactly at reset).
        static let riskThreshold: Double = 1.0

        /// Ratio threshold for underuse status (weekly quota likely left unused)
        static let underuseThreshold: Double = 0.8

        /// Ratio threshold above which overuse is shown as heavy (red instead of orange)
        static let heavyOveruseThreshold: Double = 1.2

        /// Minimum fraction of the window that must have elapsed before pace is meaningful
        /// (avoids ratio noise right after a reset)
        static let minimumElapsedFraction: Double = 0.05

        /// Minimum utilization before pace projections surface. Below this, an early
        /// front-loaded burst is treated as noise; at or above it the pace ratio,
        /// projected end, and lockout warning all surface immediately, without
        /// waiting out `minimumElapsedFraction`.
        static let minimumUsageForProjection: Double = 2.0

        /// Converts a weekly pace-days setting (5-7) into the span, in seconds, the
        /// weekly quota is expected to be consumed over.
        static func weeklyPacingDuration(days: Int) -> TimeInterval {
            TimeInterval(days) * 24 * 60 * 60
        }
    }

    /// Usage threshold configuration
    enum Thresholds {
        /// Visual status boundaries (fixed, for icon colors)
        /// These determine when the icon color changes from green → orange → red
        enum Status {
            /// Percentage where warning status begins (orange) - safe is 0..<warningStart
            static let warningStart: Double = 50
            /// Percentage where critical status begins (red) - warning is warningStart..<criticalStart
            static let criticalStart: Double = 80
        }

        /// Notification threshold configuration (user-configurable)
        enum Notification {
            /// Default warning notification threshold
            static let warningDefault: Double = 75
            /// Default critical notification threshold
            static let criticalDefault: Double = 90

            /// Slider bounds for warning threshold setting
            static let warningMin: Double = 50
            static let warningMax: Double = 90

            /// Slider bounds for critical threshold setting
            static let criticalMin: Double = 75
            static let criticalMax: Double = 100

            /// Slider step increment
            static let step: Double = 5
        }
    }
}
