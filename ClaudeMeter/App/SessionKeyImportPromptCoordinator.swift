import AppKit
import SweetCookieKit

/// Presents ClaudeMeter-owned context before macOS shows browser Safe Storage prompts.
enum SessionKeyImportPromptCoordinator {
    private static let promptLock = NSLock()

    static func install() {
        BrowserCookieKeychainPromptHandler.handler = { context in
            presentBrowserCookiePrompt(context)
        }
    }

    private static func presentBrowserCookiePrompt(_ context: BrowserCookieKeychainPromptContext) {
        let message = [
            "ClaudeMeter will ask macOS Keychain for \"\(context.label)\" so it can decrypt your Claude browser session cookie.",
            "Click OK to continue, then allow the macOS Keychain prompt.",
        ].joined(separator: " ")

        presentAlert(
            title: "Keychain Access Required",
            message: message
        )
    }

    private static func presentAlert(title: String, message: String) {
        promptLock.lock()
        defer { promptLock.unlock() }

        if Thread.isMainThread {
            MainActor.assumeIsolated {
                showAlert(title: title, message: message)
            }
            return
        }

        DispatchQueue.main.sync {
            MainActor.assumeIsolated {
                showAlert(title: title, message: message)
            }
        }
    }

    @MainActor
    private static func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        _ = alert.runModal()
    }
}
