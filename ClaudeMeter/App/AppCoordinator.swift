//
//  AppCoordinator.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-14.
//

import AppKit
import SwiftUI
import Combine

/// Root app coordinator managing navigation flow
@MainActor
final class AppCoordinator: ObservableObject {
    private let container: DIContainer
    private var setupCoordinator: SetupCoordinator?
    private var menuBarManager: MenuBarManager?
    private var cancellables = Set<AnyCancellable>()

    @Published var isSetupComplete: Bool = false

    init(container: DIContainer) {
        self.container = container
        setupNotificationObservers()
    }

    /// Setup notification observers
    private func setupNotificationObservers() {
        NotificationCenter.default.publisher(for: .openSettings)
            .sink { [weak self] _ in
                self?.showSettings()
            }
            .store(in: &cancellables)
    }

    /// Start the app flow - check for session key and show setup or main app
    func start() async {
        let hasSessionKey = await container.keychainRepository.exists(account: "default")

        if hasSessionKey {
            await showMainApp()
        } else {
            showSetup()
        }
    }

    /// Show setup wizard
    func showSetup() {
        let coordinator = SetupCoordinator(container: container) { [weak self] in
            Task { @MainActor in
                await self?.showMainApp()
            }
        }
        coordinator.showSetup()
        self.setupCoordinator = coordinator
    }

    /// Show main app (menu bar)
    func showMainApp() async {
        isSetupComplete = true

        let manager = MenuBarManager(container: container)
        await manager.setupMenuBar()

        self.menuBarManager = manager

        // Ensure dock icon is hidden
        NSApp.setActivationPolicy(.accessory)
    }

    /// Show settings window via native Settings scene
    func showSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .openClaudeMeterSettings, object: nil)
    }
}
