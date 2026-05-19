import AppKit
import Foundation

enum SystemSettingsOpener {
    static func openFullDiskAccess() {
        openSystemSettings(
            "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles",
            fallback: "x-apple.systempreferences:com.apple.preference.security"
        )
    }

    private static func openSystemSettings(_ urlString: String, fallback: String) {
        if let url = URL(string: urlString), NSWorkspace.shared.open(url) {
            return
        }

        if let fallbackURL = URL(string: fallback) {
            NSWorkspace.shared.open(fallbackURL)
        }
    }
}
