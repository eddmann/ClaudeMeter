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
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appModel: AppModel

    init() {
        let model = AppModel()
        _appModel = State(initialValue: model)
        appDelegate.configure(appModel: model)

        #if DEBUG
        if let demoMode = DemoMode.fromArguments() {
            appDelegate.configureDemoMode(true)
            DemoDataFactory.configure(model, for: demoMode)
        }
        #endif
    }

    var body: some Scene {
        Settings {
            SettingsView(appModel: appModel)
        }
        .windowResizability(.contentSize)
    }
}
