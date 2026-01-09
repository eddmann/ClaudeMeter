//
//  ClaudeMeterApp.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-14.
//

import SwiftUI

/// Main app entry point
@main
struct ClaudeMeterApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        MenuBarExtra {
            if appModel.isSetupComplete {
                UsagePopoverView(appModel: appModel)
            } else {
                SetupWizardView(appModel: appModel)
            }
        } label: {
            MenuBarLabelView(appModel: appModel)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(appModel: appModel)
        }
        .windowResizability(.contentSize)
    }
}
