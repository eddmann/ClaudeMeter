//
//  ScopedUsageSettingsTests.swift
//  ClaudeMeterTests
//

import XCTest
@testable import ClaudeMeter

final class ScopedUsageSettingsTests: XCTestCase {

    // MARK: - Settings migration

    func test_decode_withLegacyShowSonnetTrue_showsSonnet() throws {
        let settings = try decodeSettings(#"{"show_sonnet_usage": true}"#)

        XCTAssertEqual(settings.shownScopedModels, ["Sonnet"])
        XCTAssertTrue(settings.isScopedModelShown("Sonnet"))
    }

    func test_decode_withLegacyShowSonnetTrue_doesNotOptIntoOtherModels() throws {
        let settings = try decodeSettings(#"{"show_sonnet_usage": true}"#)

        XCTAssertFalse(settings.isScopedModelShown("Fable"))
    }

    func test_decode_withLegacyShowSonnetFalse_showsNothing() throws {
        let settings = try decodeSettings(#"{"show_sonnet_usage": false}"#)

        XCTAssertTrue(settings.shownScopedModels.isEmpty)
        XCTAssertFalse(settings.isScopedModelShown("Sonnet"))
        XCTAssertFalse(settings.isScopedModelShown("Fable"))
    }

    /// The settings shape written by the 1.4.0 release.
    func test_decode_settingsFromPreviousRelease_migratesCleanly() throws {
        let settings = try decodeSettings("""
        {"is_first_launch":false,"refresh_interval":60,"icon_style":"dualBar",
         "show_sonnet_usage":false,"is_colored_icon":false,"notifications_enabled":true,
         "notification_thresholds":{"critical_threshold":90,"notify_on_reset":true,"warning_threshold":75},
         "cached_organization_id":"00000000-0000-0000-0000-000000000000"}
        """)

        // Unrelated preferences survive
        XCTAssertEqual(settings.iconStyle, .dualBar)
        XCTAssertFalse(settings.isColoredIcon)
        XCTAssertEqual(settings.refreshInterval, 60)

        // The Sonnet opt-out is preserved, and nothing is opted in on the user's behalf
        XCTAssertFalse(settings.isScopedModelShown("Sonnet"))
        XCTAssertFalse(settings.isScopedModelShown("Fable"))
    }

    func test_decode_withShownScopedModels_roundTrips() throws {
        let settings = try decodeSettings(#"{"shown_scoped_models": ["Fable"]}"#)

        XCTAssertTrue(settings.isScopedModelShown("Fable"))
        XCTAssertFalse(settings.isScopedModelShown("Opus"))
    }

    func test_decode_withNeitherKey_showsNothing() throws {
        let settings = try decodeSettings("{}")

        XCTAssertTrue(settings.shownScopedModels.isEmpty)
        XCTAssertFalse(settings.isScopedModelShown("Fable"))
    }

    func test_setScopedModel_togglesVisibility() {
        var settings = AppSettings.default

        settings.setScopedModel("Fable", isShown: true)
        XCTAssertTrue(settings.isScopedModelShown("Fable"))

        settings.setScopedModel("Fable", isShown: false)
        XCTAssertFalse(settings.isScopedModelShown("Fable"))
        XCTAssertTrue(settings.shownScopedModels.isEmpty)
    }

    // MARK: - Public JSON export

    /// `~/.claudemeter/usage.json` is a documented contract for statusline scripts.
    func test_export_stillEmitsSonnetUsageForExternalTools() throws {
        let json = try exportJSON(makeUsageData(percentage: 10, scoped: [("Sonnet", 25), ("Fable", 23)]))

        let sonnet = try XCTUnwrap(json["sonnet_usage"] as? [String: Any])
        XCTAssertEqual(sonnet["utilization"] as? Double, 25)

        let scoped = try XCTUnwrap(json["scoped_usage"] as? [[String: Any]])
        XCTAssertEqual(scoped.compactMap { $0["name"] as? String }, ["Sonnet", "Fable"])
    }

    func test_export_withoutSonnet_omitsLegacyKey() throws {
        let json = try exportJSON(makeUsageData(percentage: 10, scoped: [("Fable", 23)]))

        XCTAssertNil(json["sonnet_usage"])
        XCTAssertEqual((json["scoped_usage"] as? [[String: Any]])?.count, 1)
    }

    func test_decode_legacyCacheWithSonnetUsage_becomesScopedLimit() throws {
        let json = """
        {
          "session_usage": { "utilization": 40, "reset_at": "2026-07-13T21:19:59Z" },
          "weekly_usage": { "utilization": 50, "reset_at": "2026-07-19T10:59:59Z" },
          "sonnet_usage": { "utilization": 25, "reset_at": "2026-07-19T10:59:59Z" },
          "last_updated": "2026-07-13T18:00:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = try decoder.decode(UsageData.self, from: json)

        XCTAssertEqual(data.scopedUsage.map(\.name), ["Sonnet"])
        XCTAssertEqual(data.scopedUsage.first?.limit.utilization, 25)
    }

    // MARK: - Helpers

    private func decodeSettings(_ json: String) throws -> AppSettings {
        try JSONDecoder().decode(AppSettings.self, from: json.data(using: .utf8)!)
    }

    private func exportJSON(_ data: UsageData) throws -> [String: Any] {
        let encoded = try JSONEncoder().encode(UsageExportPayload(data))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    }
}
