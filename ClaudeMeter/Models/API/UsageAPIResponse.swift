//
//  UsageAPIResponse.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-14.
//

import Foundation

/// API response for usage data
struct UsageAPIResponse: Codable {
    /// Nil when the account has no 5-hour session limit
    let fiveHour: UsageLimitResponse?
    let sevenDay: UsageLimitResponse
    let sevenDaySonnet: UsageLimitResponse?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDaySonnet = "seven_day_sonnet"
    }
}

/// Individual usage limit response from API
struct UsageLimitResponse: Codable {
    let utilization: Double // Percentage 0-100
    let resetsAt: String? // ISO8601 string, can be null

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }
}

/// Mapping error for API response conversion
enum MappingError: LocalizedError {
    case invalidDateFormat
    case missingCriticalField(field: String)

    var errorDescription: String? {
        switch self {
        case .invalidDateFormat:
            return "Server returned invalid date format"
        case .missingCriticalField(let field):
            return "Server response missing critical field: \(field)"
        }
    }
}

/// Extension to map API response to domain model
extension UsageAPIResponse {
    func toDomain() throws -> UsageData {
        let sessionLimit: UsageLimit? = try fiveHour.map { session in
            UsageLimit(
                utilization: session.utilization,
                resetAt: try parseResetDate(
                    from: session.resetsAt,
                    field: "fiveHour.resetsAt",
                    fallback: Constants.Pacing.sessionWindow
                )
            )
        }
        let weeklyResetDate = try parseResetDate(
            from: sevenDay.resetsAt,
            field: "sevenDay.resetsAt",
            fallback: Constants.Pacing.weeklyWindow
        )

        // Handle optional sonnet usage
        let sonnetLimit: UsageLimit? = try sevenDaySonnet.flatMap { sonnet -> UsageLimit? in
            let sonnetResetDate = try parseResetDate(
                from: sonnet.resetsAt,
                field: "sevenDaySonnet.resetsAt",
                fallback: Constants.Pacing.weeklyWindow
            )
            return UsageLimit(
                utilization: sonnet.utilization,
                resetAt: sonnetResetDate
            )
        }

        return UsageData(
            sessionUsage: sessionLimit,
            weeklyUsage: UsageLimit(
                utilization: sevenDay.utilization,
                resetAt: weeklyResetDate
            ),
            sonnetUsage: sonnetLimit,
            lastUpdated: Date()
        )
    }

    private func parseResetDate(
        from rawValue: String?,
        field: String,
        fallback: TimeInterval
    ) throws -> Date {
        guard let rawValue else {
            return Date().addingTimeInterval(fallback)
        }
        // The API sends timestamps both with and without fractional seconds
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let withoutFraction = ISO8601DateFormatter()
        withoutFraction.formatOptions = [.withInternetDateTime]
        guard let date = withFraction.date(from: rawValue) ?? withoutFraction.date(from: rawValue) else {
            throw MappingError.missingCriticalField(field: field)
        }
        return date
    }
}
