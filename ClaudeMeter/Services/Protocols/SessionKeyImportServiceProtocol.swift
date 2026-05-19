import Foundation

/// Browser import result for a Claude session key.
struct ImportedSessionKey: Equatable, Sendable {
    let value: String
    let sourceDescription: String
}

/// Errors that can occur while importing a session key from browser cookies.
enum SessionKeyImportError: LocalizedError {
    case noSessionKeyFound
    case accessDenied
    case safariAccessDenied
    case browserKeychainAccessDenied(String)
    case invalidImportedSessionKey

    var errorDescription: String? {
        switch self {
        case .noSessionKeyFound:
            return "No Claude browser session found. Sign in to claude.ai and try again."
        case .accessDenied:
            return "ClaudeMeter could not access browser cookies. Allow the macOS prompt or paste your session."
        case .safariAccessDenied:
            return "Safari needs Full Disk Access to import cookies. Use Chrome/Arc/Brave or paste your session."
        case .browserKeychainAccessDenied(let browserName):
            return "Allow \(browserName) Safe Storage in Keychain, or paste your session."
        case .invalidImportedSessionKey:
            return "The imported Claude session key could not be validated."
        }
    }

    var offersFullDiskAccessSettings: Bool {
        if case .safariAccessDenied = self {
            return true
        }
        return false
    }
}

/// Protocol for importing Claude session keys from local browser data.
protocol SessionKeyImportServiceProtocol: Actor {
    func importSessionKey() async throws -> ImportedSessionKey
}
