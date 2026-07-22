//
//  UsageLimitRiskTests.swift
//  ClaudeMeterTests
//
//  Created by Edd on 2026-01-16.
//

import XCTest
@testable import ClaudeMeter

final class UsageLimitRiskTests: XCTestCase {

    private let sessionWindow: TimeInterval = 5 * 60 * 60 // 5 hours

    func test_isAtRisk_whenUsingFasterThanSustainable_returnsTrue() {
        // 25% of time elapsed, 50% usage = ratio of 2.0 (> 1.0 threshold)
        let resetAt = Date().addingTimeInterval(3.75 * 60 * 60) // 3.75 hours remaining
        let usageLimit = UsageLimit(utilization: 50.0, resetAt: resetAt)

        XCTAssertTrue(usageLimit.isAtRisk(windowDuration: sessionWindow))
    }

    func test_isAtRisk_whenUsingAtSustainablePace_returnsFalse() {
        // 50% of time elapsed, 50% usage = ratio of 1.0 (at the 1.0 threshold, not above)
        let resetAt = Date().addingTimeInterval(2.5 * 60 * 60) // 2.5 hours remaining
        let usageLimit = UsageLimit(utilization: 50.0, resetAt: resetAt)

        XCTAssertFalse(usageLimit.isAtRisk(windowDuration: sessionWindow))
    }

    func test_isAtRisk_whenSlightlyAboveThreshold_returnsTrue() {
        // 50% of time elapsed, 55% usage = ratio of 1.1 (just above the 1.0 threshold)
        let resetAt = Date().addingTimeInterval(2.5 * 60 * 60) // 2.5 hours remaining
        let usageLimit = UsageLimit(utilization: 55.0, resetAt: resetAt)

        XCTAssertTrue(usageLimit.isAtRisk(windowDuration: sessionWindow))
    }

    func test_isAtRisk_whenPastResetTime_returnsFalse() {
        let resetAt = Date().addingTimeInterval(-60) // Already past
        let usageLimit = UsageLimit(utilization: 50.0, resetAt: resetAt)

        XCTAssertFalse(usageLimit.isAtRisk(windowDuration: sessionWindow))
    }

    func test_isAtRisk_whenBeforeWindowStart_returnsFalse() {
        // Reset is more than 5 hours away (window hasn't started yet)
        let resetAt = Date().addingTimeInterval(sessionWindow + 60)
        let usageLimit = UsageLimit(utilization: 50.0, resetAt: resetAt)

        XCTAssertFalse(usageLimit.isAtRisk(windowDuration: sessionWindow))
    }

    func test_resetDescription_whenUnderOneHour_showsRoundedUpMinutes() {
        XCTAssertEqual(
            UsageLimit.resetDescription(for: 45.2 * 60),
            "in 46 minutes"
        )
    }

    func test_resetDescription_whenUnderOneDay_showsRoundedUpHours() {
        XCTAssertEqual(
            UsageLimit.resetDescription(for: 3.1 * 60 * 60),
            "in 4 hours"
        )
    }

    func test_resetDescription_whenOverOneDay_showsDaysAndHours() {
        XCTAssertEqual(
            UsageLimit.resetDescription(for: 40 * 60 * 60),
            "in 1 day 16 hours"
        )
    }

    func test_resetDescription_whenExactlyWholeDays_omitsZeroHours() {
        XCTAssertEqual(
            UsageLimit.resetDescription(for: 2 * 24 * 60 * 60),
            "in 2 days"
        )
    }

    func test_resetDescription_whenPastResetTime_showsNow() {
        XCTAssertEqual(
            UsageLimit.resetDescription(for: -60),
            "now"
        )
    }
}
