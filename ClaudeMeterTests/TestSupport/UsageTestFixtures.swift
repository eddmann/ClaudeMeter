//
//  UsageTestFixtures.swift
//  ClaudeMeterTests
//

import Foundation
import XCTest
@testable import ClaudeMeter

func makeUsageData(
    percentage: Double,
    weeklyPercentage: Double = TestConstants.weeklyPercentage,
    scoped: [(name: String, percentage: Double)] = [],
    resetAt: Date = Date().addingTimeInterval(TestConstants.oneHourInterval)
) -> UsageData {
    UsageData(
        sessionUsage: UsageLimit(utilization: percentage, resetAt: resetAt),
        weeklyUsage: UsageLimit(utilization: weeklyPercentage, resetAt: resetAt),
        scopedUsage: scoped.map {
            ScopedUsageLimit(
                name: $0.name,
                limit: UsageLimit(utilization: $0.percentage, resetAt: resetAt),
                isActive: false
            )
        },
        lastUpdated: Date()
    )
}

func assertDate(
    _ date: Date,
    equalsIso8601String isoString: String,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    guard let expectedDate = formatter.date(from: isoString) else {
        XCTFail("Invalid ISO8601 test date: \(isoString)", file: file, line: line)
        return
    }

    XCTAssertEqual(
        date.timeIntervalSince1970,
        expectedDate.timeIntervalSince1970,
        accuracy: 0.001,
        file: file,
        line: line
    )
}
