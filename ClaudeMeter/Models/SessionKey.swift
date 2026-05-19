import Foundation

/// Errors that can occur when working with session keys
enum SessionKeyError: LocalizedError {
    case invalidFormat
    case tooShort
    case validationFailed

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Session key must start with 'sk-ant-'"
        case .tooShort:
            return "Session key is too short"
        case .validationFailed:
            return "Session key could not be validated with Claude API"
        }
    }
}

/// Validated Claude session key
/// Note: Not Codable to prevent accidental serialization - use Keychain instead
struct SessionKey: Equatable, Sendable {
    /// The session key value (format: sk-ant-*)
    let value: String

    /// Organization associated with this key (cached)
    var organizationId: UUID?

    /// Throwing initializer that validates format.
    /// Accepts a raw `sk-ant-*` value or a Cookie header containing `sessionKey=sk-ant-*`.
    init(_ value: String) throws {
        guard let trimmed = Self.extractSessionKeyValue(from: value) else {
            throw SessionKeyError.invalidFormat
        }

        guard trimmed.hasPrefix("sk-ant-") else {
            throw SessionKeyError.invalidFormat
        }

        guard trimmed.count > 10 else {
            throw SessionKeyError.tooShort
        }

        self.value = trimmed
    }

    static func extractSessionKeyValue(from rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasPrefix("sk-ant-") {
            return trimmed
        }

        let pattern = #"(?i)(?:^|[;\s])sessionKey\s*=\s*([^;\s'"]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        guard let match = regex.firstMatch(in: trimmed, range: range),
              match.numberOfRanges >= 2,
              let captureRange = Range(match.range(at: 1), in: trimmed) else {
            return nil
        }

        return String(trimmed[captureRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
