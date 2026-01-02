//
//  HiddenWindowView.swift
//  ClaudeMeter
//
//  Created by Edd on 2026-01-02.
//

import SwiftUI

/// Notification to open settings from anywhere in the app
extension Notification.Name {
    static let openClaudeMeterSettings = Notification.Name("openClaudeMeterSettings")
    static let settingsDidChange = Notification.Name("settingsDidChange")
    static let iconStylePreviewChanged = Notification.Name("iconStylePreviewChanged")
}

/// Invisible view that keeps SwiftUI's lifecycle alive for the Settings scene.
/// This window is positioned off-screen and made completely invisible.
struct HiddenWindowView: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .onReceive(NotificationCenter.default.publisher(for: .openClaudeMeterSettings)) { _ in
                openSettings()
            }
            .onAppear {
                // Find and hide the lifecycle window
                DispatchQueue.main.async {
                    for window in NSApp.windows {
                        // Match by title or by being a tiny window
                        if window.title == "ClaudeMeterLifecycle" ||
                           (window.frame.width <= 20 && window.frame.height <= 20) {
                            // Make the keepalive window truly invisible and non-interactive
                            window.styleMask = [.borderless]
                            window.collectionBehavior = [.auxiliary, .ignoresCycle, .transient, .canJoinAllSpaces]
                            window.isExcludedFromWindowsMenu = true
                            window.level = .floating
                            window.isOpaque = false
                            window.alphaValue = 0
                            window.backgroundColor = .clear
                            window.hasShadow = false
                            window.ignoresMouseEvents = true
                            window.canHide = false
                            window.setContentSize(NSSize(width: 1, height: 1))
                            window.setFrameOrigin(NSPoint(x: -5000, y: -5000))
                            break
                        }
                    }
                }
            }
    }
}
