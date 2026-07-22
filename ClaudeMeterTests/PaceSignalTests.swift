//
//  PaceSignalTests.swift
//  ClaudeMeterTests
//
//  Created by Edd on 2026-07-17.
//

import XCTest
@testable import ClaudeMeter

final class PaceSignalTests: XCTestCase {

    private let sessionWindow = Constants.Pacing.sessionWindow
    private let weeklyWindow = Constants.Pacing.weeklyWindow

    // MARK: - Helpers

    /// Builds a limit whose window has `elapsedFraction` of `window` elapsed, with `utilization` used.
    private func limit(utilization: Double, elapsedFraction: Double, window: TimeInterval) -> UsageLimit {
        let remaining = window * (1 - elapsedFraction)
        return UsageLimit(utilization: utilization, resetAt: Date().addingTimeInterval(remaining))
    }

    private func usageData(session: UsageLimit, weekly: UsageLimit) -> UsageData {
        UsageData(sessionUsage: session, weeklyUsage: weekly, sonnetUsage: nil, lastUpdated: Date())
    }

    // MARK: - paceRatio

    func test_paceRatio_atSustainablePace_isOne() {
        let usageLimit = limit(utilization: 50, elapsedFraction: 0.5, window: sessionWindow)
        XCTAssertEqual(usageLimit.paceRatio(windowDuration: sessionWindow) ?? 0, 1.0, accuracy: 0.01)
    }

    func test_paceRatio_burningFast_isAboveOne() {
        // 50% used at 25% elapsed = 2.0
        let usageLimit = limit(utilization: 50, elapsedFraction: 0.25, window: sessionWindow)
        XCTAssertEqual(usageLimit.paceRatio(windowDuration: sessionWindow) ?? 0, 2.0, accuracy: 0.01)
    }

    func test_paceRatio_underusing_isBelowOne() {
        // 20% used at 50% elapsed = 0.4
        let usageLimit = limit(utilization: 20, elapsedFraction: 0.5, window: weeklyWindow)
        XCTAssertEqual(usageLimit.paceRatio(windowDuration: weeklyWindow) ?? 0, 0.4, accuracy: 0.01)
    }

    func test_paceRatio_withinGracePeriod_belowUsageFloor_isNil() {
        // 1% used in the first 2% of the window: below both the elapsed grace and
        // the usage floor, so the ratio stays suppressed as noise.
        let usageLimit = limit(utilization: 1, elapsedFraction: 0.02, window: sessionWindow)
        XCTAssertNil(usageLimit.paceRatio(windowDuration: sessionWindow))
    }

    func test_paceRatio_withinGracePeriod_aboveUsageFloor_surfaces() {
        // A front-loaded burst clears the usage floor, so the ratio surfaces before
        // the elapsed grace ends: 10% used at 2% elapsed -> 5.0.
        let usageLimit = limit(utilization: 10, elapsedFraction: 0.02, window: sessionWindow)
        XCTAssertEqual(usageLimit.paceRatio(windowDuration: sessionWindow) ?? 0, 5.0, accuracy: 0.01)
    }

    func test_paceRatio_pastReset_isNil() {
        let usageLimit = UsageLimit(utilization: 50, resetAt: Date().addingTimeInterval(-60))
        XCTAssertNil(usageLimit.paceRatio(windowDuration: sessionWindow))
    }

    // MARK: - UsageData.paceSignal (hybrid rule)

    func test_paceSignal_sessionBurningFast_isHotFromSessionWindow() {
        let data = usageData(
            session: limit(utilization: 50, elapsedFraction: 0.25, window: sessionWindow),
            weekly: limit(utilization: 50, elapsedFraction: 0.5, window: weeklyWindow)
        )

        let signal = data.paceSignal(weeklyPaceDays: 7)
        XCTAssertEqual(signal?.kind, .hot)
        XCTAssertEqual(signal?.windowName, "5-hour")
    }

    func test_paceSignal_bothHot_picksHigherRatio() {
        let data = usageData(
            session: limit(utilization: 60, elapsedFraction: 0.4, window: sessionWindow),   // 1.5
            weekly: limit(utilization: 90, elapsedFraction: 0.3, window: weeklyWindow)      // 3.0
        )

        let signal = data.paceSignal(weeklyPaceDays: 7)
        XCTAssertEqual(signal?.kind, .hot)
        XCTAssertEqual(signal?.windowName, "7-day")
    }

    func test_paceSignal_weeklyUnderused_isCold() {
        let data = usageData(
            session: limit(utilization: 50, elapsedFraction: 0.5, window: sessionWindow),
            weekly: limit(utilization: 20, elapsedFraction: 0.5, window: weeklyWindow)      // 0.4
        )

        let signal = data.paceSignal(weeklyPaceDays: 7)
        XCTAssertEqual(signal?.kind, .cold)
        XCTAssertEqual(signal?.windowName, "7-day")
    }

    func test_paceSignal_sessionIdleButWeeklyOnPace_isNil() {
        // Session underuse alone must not produce a cold signal
        let data = usageData(
            session: limit(utilization: 10, elapsedFraction: 0.8, window: sessionWindow),   // 0.125
            weekly: limit(utilization: 50, elapsedFraction: 0.5, window: weeklyWindow)      // 1.0
        )

        XCTAssertNil(data.paceSignal(weeklyPaceDays: 7))
    }

    func test_paceSignal_sessionHotWinsOverWeeklyCold() {
        // Imminent session lockout beats long-term weekly underuse
        let data = usageData(
            session: limit(utilization: 50, elapsedFraction: 0.25, window: sessionWindow),  // 2.0
            weekly: limit(utilization: 20, elapsedFraction: 0.5, window: weeklyWindow)      // 0.4
        )

        XCTAssertEqual(data.paceSignal(weeklyPaceDays: 7)?.kind, .hot)
    }

    func test_paceSignal_onPaceEverywhere_isNil() {
        let data = usageData(
            session: limit(utilization: 50, elapsedFraction: 0.5, window: sessionWindow),
            weekly: limit(utilization: 50, elapsedFraction: 0.5, window: weeklyWindow)
        )

        XCTAssertNil(data.paceSignal(weeklyPaceDays: 7))
    }

    // MARK: - Weekly pace basis (5/6/7 days)

    func test_paceRatio_fiveDayPacing_expectsFasterBurn() {
        // 40% used at 2 of 7 days elapsed: on 5-day basis expected is 40% -> ratio 1.0
        let usageLimit = limit(utilization: 40, elapsedFraction: 2.0 / 7.0, window: weeklyWindow)
        let fiveDays: TimeInterval = 5 * 24 * 60 * 60

        XCTAssertEqual(
            usageLimit.paceRatio(windowDuration: weeklyWindow, pacingDuration: fiveDays) ?? 0,
            1.0,
            accuracy: 0.01
        )
    }

    func test_paceRatio_pastPacingDuration_capsElapsedAtFull() {
        // Day 6 of 7 on a 5-day basis: expected usage is 100%, so ratio equals usage fraction
        let usageLimit = limit(utilization: 70, elapsedFraction: 6.0 / 7.0, window: weeklyWindow)
        let fiveDays: TimeInterval = 5 * 24 * 60 * 60

        XCTAssertEqual(
            usageLimit.paceRatio(windowDuration: weeklyWindow, pacingDuration: fiveDays) ?? 0,
            0.7,
            accuracy: 0.01
        )
    }

    // MARK: - Projection

    func test_projectedEndPercent_extrapolatesCurrentRate() {
        // 40% used at 50% elapsed -> 80% at window end
        let usageLimit = limit(utilization: 40, elapsedFraction: 0.5, window: sessionWindow)

        XCTAssertEqual(
            usageLimit.projectedEndPercent(windowDuration: sessionWindow) ?? 0,
            80,
            accuracy: 0.5
        )
    }

    func test_projectedEndPercent_withinGracePeriod_aboveUsageFloor_surfaces() {
        // 10% used at 2% elapsed extrapolates to 500% - surfaces once the usage
        // floor is cleared, without waiting out the elapsed grace.
        let usageLimit = limit(utilization: 10, elapsedFraction: 0.02, window: sessionWindow)
        XCTAssertEqual(usageLimit.projectedEndPercent(windowDuration: sessionWindow) ?? 0, 500, accuracy: 1)
    }

    func test_projectedEndPercent_withinGracePeriod_belowUsageFloor_isNil() {
        // Trivial early usage stays suppressed - below both grace and usage floor.
        let usageLimit = limit(utilization: 1, elapsedFraction: 0.02, window: sessionWindow)
        XCTAssertNil(usageLimit.projectedEndPercent(windowDuration: sessionWindow))
    }

    func test_projectedLimitDate_whenBurningFast_isBeforeReset() {
        // 60% used at 50% elapsed -> hits 100% at ~83% of the window, before reset
        let usageLimit = limit(utilization: 60, elapsedFraction: 0.5, window: sessionWindow)

        guard let hitDate = usageLimit.projectedLimitDate(windowDuration: sessionWindow) else {
            return XCTFail("Expected a projected limit date")
        }
        XCTAssertLessThan(hitDate, usageLimit.resetAt)

        // Hit at elapsed * 100/60 = 0.833 of the window
        let windowStart = usageLimit.resetAt.addingTimeInterval(-sessionWindow)
        let hitFraction = hitDate.timeIntervalSince(windowStart) / sessionWindow
        XCTAssertEqual(hitFraction, 5.0 / 6.0, accuracy: 0.01)
    }

    func test_projectedLimitDate_whenOnSustainablePace_isNil() {
        let usageLimit = limit(utilization: 50, elapsedFraction: 0.5, window: sessionWindow)
        XCTAssertNil(usageLimit.projectedLimitDate(windowDuration: sessionWindow))
    }

    func test_projectedLimitDate_whenAlreadyExceeded_isNil() {
        let usageLimit = limit(utilization: 105, elapsedFraction: 0.5, window: sessionWindow)
        XCTAssertNil(usageLimit.projectedLimitDate(windowDuration: sessionWindow))
    }

    func test_projectedLimitDate_frontLoadedBurstWithinGracePeriod_stillWarns() {
        // 60% burned in the first ~2% of the window - below the pace grace period,
        // but a lockout is unambiguous, so the projection must still fire.
        let usageLimit = limit(utilization: 60, elapsedFraction: 0.02, window: sessionWindow)
        // The migration surfaces the ratio too once usage clears the floor: 60% at 2% elapsed -> 30.0.
        XCTAssertEqual(usageLimit.paceRatio(windowDuration: sessionWindow) ?? 0, 30.0, accuracy: 0.01,
                       "usage floor surfaces the ratio inside the elapsed grace")

        guard let hitDate = usageLimit.projectedLimitDate(windowDuration: sessionWindow) else {
            return XCTFail("Expected an early limit projection for a heavy front-loaded burn")
        }
        XCTAssertLessThan(hitDate, usageLimit.resetAt)
    }

    func test_projectedLimitDate_trivialEarlyUsage_isNil() {
        // 1% used moments after reset is noise, not a lockout - below the usage floor.
        let usageLimit = limit(utilization: 1, elapsedFraction: 0.01, window: sessionWindow)
        XCTAssertNil(usageLimit.projectedLimitDate(windowDuration: sessionWindow))
    }

    func test_projection_respectsPacingBasis_noContradiction() {
        // 60% used at 4/7 of the week, paced over 5 days: ratio is under-pace (< 0.8),
        // so the projection must agree - end below 100%, no limit-hit warning.
        let fiveDays = Constants.Pacing.weeklyPacingDuration(days: 5)
        let usageLimit = limit(utilization: 60, elapsedFraction: 4.0 / 7.0, window: weeklyWindow)

        let ratio = usageLimit.paceRatio(windowDuration: weeklyWindow, pacingDuration: fiveDays) ?? 0
        XCTAssertLessThan(ratio, Constants.Pacing.underuseThreshold)

        XCTAssertNil(usageLimit.projectedLimitDate(windowDuration: weeklyWindow, pacingDuration: fiveDays))
        let end = usageLimit.projectedEndPercent(windowDuration: weeklyWindow, pacingDuration: fiveDays) ?? 0
        XCTAssertLessThan(end, 100)
    }

    // MARK: - Tooltip

    func test_tooltip_cold_showsUsedVsExpectedAndPaceBasis() {
        let signal = PaceSignal(
            kind: .cold, ratio: 0.29, windowName: "7-day",
            usedPercent: 11.4, expectedPercent: 40, paceDays: 5
        )

        XCTAssertEqual(
            signal.tooltip,
            "Used 11% vs 40% expected by now - 0.3× pace, quota may go unused (5/7-day window)"
        )
    }

    func test_tooltip_hot_omitsPaceBasisForSessionWindow() {
        let signal = PaceSignal(
            kind: .hot, ratio: 1.8, windowName: "5-hour",
            usedPercent: 72, expectedPercent: 40, paceDays: nil
        )

        XCTAssertEqual(
            signal.tooltip,
            "Used 72% vs 40% expected by now - burning 1.8× sustainable pace (5-hour window)"
        )
    }

    func test_paceSignal_zeroUtilization_hasZeroRatioAndFiniteExpected() {
        let data = usageData(
            session: limit(utilization: 50, elapsedFraction: 0.5, window: sessionWindow),
            weekly: limit(utilization: 0, elapsedFraction: 0.5, window: weeklyWindow)
        )

        let signal = data.paceSignal(weeklyPaceDays: 7)
        XCTAssertEqual(signal?.kind, .cold)
        XCTAssertEqual(signal?.ratio ?? -1, 0, accuracy: 0.001)
        XCTAssertEqual(signal?.expectedPercent ?? 0, 50, accuracy: 1)
    }

    func test_paceSignal_hotOnSevenDayBasis_notHotOnFiveDayBasis() {
        // Weekly 40% used at 2 of 7 days elapsed: 7-day ratio 1.4 (hot), 5-day ratio 1.0 (on pace)
        let data = usageData(
            session: limit(utilization: 50, elapsedFraction: 0.5, window: sessionWindow),
            weekly: limit(utilization: 40, elapsedFraction: 2.0 / 7.0, window: weeklyWindow)
        )

        XCTAssertEqual(data.paceSignal(weeklyPaceDays: 7)?.kind, .hot)
        XCTAssertNil(data.paceSignal(weeklyPaceDays: 5))
    }

    // MARK: - fallbackPaceRatio (menu bar, no off-pace signal)

    func test_fallbackPaceRatio_leadsWithWorstWindowNotSession() {
        // No off-pace signal: the session idles at ~0.1x while the weekly window
        // is on pace at 1.0x. The menu bar must lead with the worst (highest)
        // ratio, not default to the idle session.
        let data = usageData(
            session: limit(utilization: 7, elapsedFraction: 0.64, window: sessionWindow),   // ~0.11
            weekly: limit(utilization: 13, elapsedFraction: 0.13, window: weeklyWindow)      // 1.0
        )

        XCTAssertNil(data.paceSignal(weeklyPaceDays: 7), "neither window is off pace")
        XCTAssertEqual(data.fallbackPaceRatio(weeklyPaceDays: 7) ?? 0, 1.0, accuracy: 0.02)
    }

    func test_fallbackPaceRatio_isNilWhenBothWindowsSuppressed() {
        // Both barely started and below the usage floor: no ratio to lead with.
        let data = usageData(
            session: limit(utilization: 1, elapsedFraction: 0.02, window: sessionWindow),
            weekly: limit(utilization: 1, elapsedFraction: 0.02, window: weeklyWindow)
        )

        XCTAssertNil(data.fallbackPaceRatio(weeklyPaceDays: 7))
    }
}
