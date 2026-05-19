import Foundation
import os
import SweetCookieKit

/// Imports Claude session keys from local browser cookies.
actor SessionKeyImportService: SessionKeyImportServiceProtocol {
    private static let logger = Logger(subsystem: "com.claudemeter", category: "SessionKeyImportService")

    private let cookieClient: BrowserCookieClient
    private let browserImportOrder: [Browser]

    init(
        cookieClient: BrowserCookieClient = BrowserCookieClient(),
        browserImportOrder: [Browser] = Browser.defaultImportOrder
    ) {
        self.cookieClient = cookieClient
        self.browserImportOrder = browserImportOrder
    }

    func importSessionKey() async throws -> ImportedSessionKey {
        let query = BrowserCookieQuery(domains: ["claude.ai"], domainMatch: .suffix)
        var sawAccessDenied = false
        var sawSafariAccessDenied = false
        var deniedKeychainBrowserName: String?

        for browser in browserImportOrder {
            do {
                let sources = try cookieClient.records(matching: query, in: browser)
                for source in sources {
                    if let imported = try importedSessionKey(from: source) {
                        return imported
                    }
                }
            } catch let error as BrowserCookieError {
                switch error {
                case .accessDenied:
                    sawAccessDenied = true
                    if browser == .safari {
                        sawSafariAccessDenied = true
                    } else if browser.usesKeychainForCookieDecryption {
                        deniedKeychainBrowserName = browser.displayName
                    }
                case .notFound, .loadFailed:
                    break
                }
                Self.logger.debug("Browser cookie import failed for \(browser.displayName): \(error.localizedDescription)")
            } catch {
                Self.logger.debug("Browser cookie import failed for \(browser.displayName): \(error.localizedDescription)")
            }
        }

        if let deniedKeychainBrowserName {
            throw SessionKeyImportError.browserKeychainAccessDenied(deniedKeychainBrowserName)
        }
        if sawSafariAccessDenied {
            throw SessionKeyImportError.safariAccessDenied
        }
        if sawAccessDenied {
            throw SessionKeyImportError.accessDenied
        }
        throw SessionKeyImportError.noSessionKeyFound
    }

    private func importedSessionKey(from source: BrowserCookieStoreRecords) throws -> ImportedSessionKey? {
        guard let cookie = source.records.first(where: { $0.name == "sessionKey" }) else {
            return nil
        }

        let sessionKey = try SessionKey(cookie.value)
        return ImportedSessionKey(
            value: sessionKey.value,
            sourceDescription: source.label
        )
    }
}

private extension Browser {
    var usesKeychainForCookieDecryption: Bool {
        switch self {
        case .safari, .firefox, .zen:
            return false
        case .chrome, .chromeBeta, .chromeCanary,
             .arc, .arcBeta, .arcCanary,
             .chatgptAtlas,
             .chromium,
             .yandex,
             .brave, .braveBeta, .braveNightly,
             .edge, .edgeBeta, .edgeCanary,
             .helium,
             .vivaldi,
             .dia,
             .comet:
            return true
        @unknown default:
            return true
        }
    }
}
