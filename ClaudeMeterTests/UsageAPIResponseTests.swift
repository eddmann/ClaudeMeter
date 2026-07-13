//
//  UsageAPIResponseTests.swift
//  ClaudeMeterTests
//

import XCTest
@testable import ClaudeMeter

final class UsageAPIResponseTests: XCTestCase {

    // MARK: - Current API shape (`limits` array)

    /// Mirrors the shape the API returns. The flat per-model fields are null — the
    /// model-specific data lives only in `limits`.
    private let liveResponse = """
    {
      "five_hour": {
        "utilization": 30,
        "resets_at": "2026-01-01T12:00:00.123456+00:00"
      },
      "seven_day": {
        "utilization": 40,
        "resets_at": "2026-01-05T00:00:00.123456+00:00"
      },
      "seven_day_opus": null,
      "seven_day_sonnet": null,
      "limits": [
        {
          "kind": "session",
          "group": "session",
          "percent": 30,
          "severity": "normal",
          "resets_at": "2026-01-01T12:00:00.123456+00:00",
          "scope": null,
          "is_active": false
        },
        {
          "kind": "weekly_all",
          "group": "weekly",
          "percent": 40,
          "severity": "normal",
          "resets_at": "2026-01-05T00:00:00.123456+00:00",
          "scope": null,
          "is_active": false
        },
        {
          "kind": "weekly_scoped",
          "group": "weekly",
          "percent": 50,
          "severity": "normal",
          "resets_at": "2026-01-05T00:00:00.123456+00:00",
          "scope": {
            "model": { "id": null, "display_name": "Fable" },
            "surface": null
          },
          "is_active": true
        }
      ]
    }
    """.data(using: .utf8)!

    func test_toDomain_withLimitsArray_mapsSessionAndWeekly() throws {
        let usageData = try decode(liveResponse).toDomain()

        XCTAssertEqual(usageData.sessionUsage.utilization, 30)
        XCTAssertEqual(usageData.weeklyUsage.utilization, 40)
    }

    func test_toDomain_withLimitsArray_surfacesScopedModelByDisplayName() throws {
        let usageData = try decode(liveResponse).toDomain()

        XCTAssertEqual(usageData.scopedUsage.count, 1)

        let fable = try XCTUnwrap(usageData.scopedUsage.first)
        XCTAssertEqual(fable.name, "Fable")
        XCTAssertEqual(fable.limit.utilization, 50)
        XCTAssertTrue(fable.isActive)
        XCTAssertEqual(fable.title, "Weekly Fable")
    }

    func test_toDomain_withUnknownFutureModel_surfacesItAnyway() throws {
        let json = """
        {
          "limits": [
            { "kind": "session", "percent": 10, "resets_at": null, "scope": null, "is_active": false },
            { "kind": "weekly_all", "percent": 20, "resets_at": null, "scope": null, "is_active": false },
            {
              "kind": "weekly_scoped",
              "percent": 66,
              "resets_at": null,
              "scope": { "model": { "id": null, "display_name": "Nonesuch 9" }, "surface": null },
              "is_active": true
            }
          ]
        }
        """.data(using: .utf8)!

        let usageData = try decode(json).toDomain()

        XCTAssertEqual(usageData.scopedUsage.map(\.name), ["Nonesuch 9"])
        XCTAssertEqual(usageData.scopedUsage.first?.limit.utilization, 66)
    }

    func test_toDomain_withMultipleScopedLimits_preservesAPIOrder() throws {
        let json = """
        {
          "limits": [
            { "kind": "session", "percent": 1, "resets_at": null, "scope": null, "is_active": false },
            { "kind": "weekly_all", "percent": 2, "resets_at": null, "scope": null, "is_active": false },
            { "kind": "weekly_scoped", "percent": 23, "resets_at": null,
              "scope": { "model": { "id": null, "display_name": "Fable" } }, "is_active": true },
            { "kind": "weekly_scoped", "percent": 58, "resets_at": null,
              "scope": { "model": { "id": null, "display_name": "Opus" } }, "is_active": false }
          ]
        }
        """.data(using: .utf8)!

        let usageData = try decode(json).toDomain()

        XCTAssertEqual(usageData.scopedUsage.map(\.name), ["Fable", "Opus"])
    }

    func test_toDomain_withUnrecognisedScopeShape_doesNotThrow() throws {
        let json = """
        {
          "limits": [
            { "kind": "session", "percent": 3, "resets_at": null, "scope": null, "is_active": false },
            { "kind": "weekly_all", "percent": 4, "resets_at": null, "scope": null, "is_active": false },
            { "kind": "weekly_scoped", "percent": 30, "resets_at": null,
              "scope": { "model": "just-a-string", "surface": 42 }, "is_active": true }
          ]
        }
        """.data(using: .utf8)!

        let usageData = try decode(json).toDomain()

        XCTAssertEqual(usageData.sessionUsage.utilization, 3)
        XCTAssertTrue(usageData.scopedUsage.isEmpty)
    }

    func test_toDomain_missingSessionLimit_throws() throws {
        let json = """
        { "limits": [ { "kind": "weekly_all", "percent": 4, "resets_at": null, "scope": null, "is_active": false } ] }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try decode(json).toDomain())
    }

    func test_toDomain_withScopeOnHeadlineEntry_doesNotDuplicateIt() throws {
        let json = """
        {
          "limits": [
            { "kind": "session", "percent": 5, "resets_at": null, "scope": null, "is_active": false },
            { "kind": "weekly_all", "percent": 14, "resets_at": null,
              "scope": { "model": { "id": null, "display_name": "Fable" } }, "is_active": false }
          ]
        }
        """.data(using: .utf8)!

        let usageData = try decode(json).toDomain()

        XCTAssertEqual(usageData.weeklyUsage.utilization, 14)
        XCTAssertTrue(usageData.scopedUsage.isEmpty)
    }

    // MARK: - Legacy API shape (no `limits` array)

    func test_toDomain_withoutLimits_fallsBackToFlatFields() throws {
        let json = """
        {
          "five_hour": { "utilization": 40, "resets_at": null },
          "seven_day": { "utilization": 50, "resets_at": null },
          "seven_day_sonnet": { "utilization": 25, "resets_at": null }
        }
        """.data(using: .utf8)!

        let usageData = try decode(json).toDomain()

        XCTAssertEqual(usageData.sessionUsage.utilization, 40)
        XCTAssertEqual(usageData.weeklyUsage.utilization, 50)
        XCTAssertEqual(usageData.scopedUsage.map(\.name), ["Sonnet"])
        XCTAssertEqual(usageData.scopedUsage.first?.limit.utilization, 25)
    }

    // MARK: - Timestamps

    func test_toDomain_parsesTimestampsWithAndWithoutFractionalSeconds() throws {
        let json = """
        {
          "limits": [
            { "kind": "session", "percent": 5, "resets_at": "2026-01-01T12:00:00.123456+00:00",
              "scope": null, "is_active": false },
            { "kind": "weekly_all", "percent": 14, "resets_at": "2026-01-05T00:00:00Z",
              "scope": null, "is_active": false }
          ]
        }
        """.data(using: .utf8)!

        let usageData = try decode(json).toDomain()

        assertDate(usageData.sessionUsage.resetAt, equalsIso8601String: "2026-01-01T12:00:00.123456+00:00")
        assertDate(usageData.weeklyUsage.resetAt, equalsIso8601String: "2026-01-05T00:00:00.000Z")
    }

    // MARK: - Helpers

    private func decode(_ data: Data) throws -> UsageAPIResponse {
        try JSONDecoder().decode(UsageAPIResponse.self, from: data)
    }
}
