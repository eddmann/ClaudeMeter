//
//  SettingsCoordinator.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-14.
//

import AppKit
import SwiftUI

/// Coordinator for settings window navigation
@MainActor
final class SettingsCoordinator: NSObject, SettingsCoordinatorProtocol {
    /// Show the settings window using native Settings scene
    func showSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .openClaudeMeterSettings, object: nil)
    }

    /// Close the settings window (no-op with native Settings scene)
    func closeSettings() {
        // Native Settings scene handles its own lifecycle
    }

    /// Handle settings changes
    func handleSettingsChanged() {
        NotificationCenter.default.post(
            name: .settingsDidChange,
            object: nil
        )
    }
}
