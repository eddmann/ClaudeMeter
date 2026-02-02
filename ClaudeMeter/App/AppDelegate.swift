//
//  AppDelegate.swift
//  ClaudeMeter
//
//  Created by Edd on 2026-01-14.
//

import AppKit

/// App delegate to manage menu bar lifecycle.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var appModel: AppModel?
    private var menuBarManager: MenuBarManager?

    #if DEBUG
    private var isDemoMode: Bool = false
    #endif

    func configure(appModel: AppModel) {
        self.appModel = appModel
    }

    #if DEBUG
    func configureDemoMode(_ enabled: Bool) {
        isDemoMode = enabled
    }
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let appModel else {
            let fallbackModel = AppModel()
            self.appModel = fallbackModel
            startMenuBar(with: fallbackModel)
            return
        }
        startMenuBar(with: appModel)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func startMenuBar(with appModel: AppModel) {
        let manager = MenuBarManager(appModel: appModel)
        menuBarManager = manager

        #if DEBUG
        if isDemoMode {
            manager.startWithoutBootstrap()
        } else {
            manager.start()
        }
        #else
        manager.start()
        #endif
    }
}
