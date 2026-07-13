//
//  MenuBarIconSnapshotTests.swift
//  ClaudeMeterTests
//
//  Created by Edd on 2026-01-09.
//

import AppKit
import SnapshotTesting
import XCTest
@testable import ClaudeMeter

@MainActor
final class MenuBarIconSnapshotTests: XCTestCase {
    /// SwiftUI renders gradients and antialiased edges differently across macOS versions,
    /// so a pixel-exact comparison fails on any OS other than the one that recorded the
    /// references. Compare perceptually instead.
    ///
    /// The tolerance is sized from measurement, not taste: the same icon rendered on a
    /// newer macOS drifts by at most ~10 ΔE, while a genuinely different icon differs by
    /// ~128 ΔE. Allowing ΔE ≤ 10 absorbs the drift and still leaves a 12x margin.
    private let strategy: Snapshotting<NSImage, NSImage> = .image(
        precision: 0.99,
        perceptualPrecision: 0.90
    )

    func test_menuBarIcon_showsBatteryStyleWhenWarning() {
        let image = renderIcon(style: .battery)

        assertSnapshot(of: image, as: strategy, record: isRecording)
    }

    func test_menuBarIcon_showsCircularStyleWhenWarning() {
        let image = renderIcon(style: .circular)

        assertSnapshot(of: image, as: strategy, record: isRecording)
    }

    func test_menuBarIcon_showsMinimalStyleWhenWarning() {
        let image = renderIcon(style: .minimal)

        assertSnapshot(of: image, as: strategy, record: isRecording)
    }

    func test_menuBarIcon_showsSegmentsStyleWhenWarning() {
        let image = renderIcon(style: .segments)

        assertSnapshot(of: image, as: strategy, record: isRecording)
    }

    func test_menuBarIcon_showsDualBarStyleWhenWarning() {
        let image = renderIcon(style: .dualBar)

        assertSnapshot(of: image, as: strategy, record: isRecording)
    }

    func test_menuBarIcon_showsGaugeStyleWhenWarning() {
        let image = renderIcon(style: .gauge)

        assertSnapshot(of: image, as: strategy, record: isRecording)
    }

    func test_menuBarIcon_showsLoadingIndicatorInBatteryStyle() {
        let image = renderIcon(style: .battery, status: .safe, isLoading: true)

        assertSnapshot(of: image, as: strategy, record: isRecording)
    }

    func test_menuBarIcon_showsStaleIndicatorInBatteryStyle() {
        let image = renderIcon(style: .battery, status: .safe, isStale: true)

        assertSnapshot(of: image, as: strategy, record: isRecording)
    }

    /// Keeps the tolerance above honest: it must still reject an icon whose status colour
    /// changed, otherwise the snapshots assert nothing.
    func test_snapshotTolerance_rejectsChangedStatusColour() {
        let warning = renderIcon(style: .battery, status: .warning)
        let critical = renderIcon(style: .battery, status: .critical)

        XCTAssertNotNil(
            strategy.diffing.diff(warning, critical),
            "Tolerance is too loose: a changed status colour compares as unchanged"
        )
    }

    private func renderIcon(
        style: IconStyle,
        status: UsageStatus = .warning,
        isLoading: Bool = false,
        isStale: Bool = false
    ) -> NSImage {
        MenuBarIconSnapshotRenderer.render(
            percentage: TestConstants.menuBarSnapshotPercentage,
            weeklyPercentage: TestConstants.menuBarSnapshotWeeklyPercentage,
            status: status,
            isLoading: isLoading,
            isStale: isStale,
            iconStyle: style
        )
    }

    private var isRecording: Bool {
        #if SNAPSHOT_RECORDING
        return true
        #else
        return ProcessInfo.processInfo.environment["SNAPSHOT_RECORD"] == "1"
            || ProcessInfo.processInfo.arguments.contains("SNAPSHOT_RECORD")
        #endif
    }
}
