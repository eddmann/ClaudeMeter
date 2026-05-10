//
//  MenuBarManager.swift
//  ClaudeMeter
//
//  Created by Edd on 2026-01-14.
//

import AppKit
import Observation
import SwiftUI

/// Sentinel id for the setup status item shown when no accounts are configured.
private let setupSentinel = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

/// Manages NSStatusItem and NSPopover presentation. One status item per Claude account, plus a
/// single setup status item when no accounts are configured.
@MainActor
final class MenuBarManager {
    private let appModel: AppModel
    private let iconCache = IconCache()
    private let iconRenderer = MenuBarIconRenderer()
    private var openUsageObserver: NSObjectProtocol?

    private struct ManagedItem {
        let statusItem: NSStatusItem
        let popover: NSPopover
    }

    private var managedItems: [UUID: ManagedItem] = [:]

    init(appModel: AppModel) {
        self.appModel = appModel
    }

    func start() {
        observeUpdates()
        observeOpenPopoverRequests()

        Task {
            await appModel.bootstrap()
            await MainActor.run { self.reconcileItems() }
        }
    }

    #if DEBUG
    func startWithoutBootstrap() {
        observeUpdates()
        observeOpenPopoverRequests()
        reconcileItems()
    }
    #endif

    deinit {
        if let openUsageObserver {
            NotificationCenter.default.removeObserver(openUsageObserver)
        }
    }

    // MARK: - Observation

    private func observeUpdates() {
        withObservationTracking {
            // Track everything that affects the menu bar layout or icon contents.
            _ = appModel.settings.accounts
            _ = appModel.settings.iconStyle
            _ = appModel.accountStates
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.reconcileItems()
                self.observeUpdates()
            }
        }
    }

    private func observeOpenPopoverRequests() {
        openUsageObserver = NotificationCenter.default.addObserver(
            forName: .openUsagePopover,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.showFirstPopover()
            }
        }
    }

    // MARK: - Reconciliation

    /// Bring the set of status items into sync with the current account list.
    private func reconcileItems() {
        let accounts = appModel.settings.accounts

        if accounts.isEmpty {
            // Remove any per-account items, ensure setup item exists.
            for (id, item) in managedItems where id != setupSentinel {
                NSStatusBar.system.removeStatusItem(item.statusItem)
                managedItems[id] = nil
            }
            if managedItems[setupSentinel] == nil {
                managedItems[setupSentinel] = makeStatusItem(for: nil)
            }
            updateSetupItemIcon()
            return
        }

        // Drop the setup item once at least one account is configured.
        if let setup = managedItems[setupSentinel] {
            NSStatusBar.system.removeStatusItem(setup.statusItem)
            managedItems[setupSentinel] = nil
        }

        // Remove items for accounts that no longer exist.
        let configuredIds = Set(accounts.map(\.id))
        for id in managedItems.keys where !configuredIds.contains(id) {
            if let item = managedItems[id] {
                NSStatusBar.system.removeStatusItem(item.statusItem)
            }
            managedItems[id] = nil
        }

        // Ensure each account has an item, then refresh icons.
        for account in accounts {
            if managedItems[account.id] == nil {
                managedItems[account.id] = makeStatusItem(for: account)
            }
            updateIcon(for: account)
        }
    }

    private func makeStatusItem(for account: ClaudeAccount?) -> ManagedItem {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.imagePosition = .imageOnly
            button.setAccessibilityLabel(account?.label ?? "ClaudeMeter")
            // Encode the account id (or sentinel) into the action via the button's identifier.
            button.identifier = NSUserInterfaceItemIdentifier((account?.id ?? setupSentinel).uuidString)
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let popoverAccountId = account?.id
        let popoverView = MenuBarPopoverView(
            appModel: appModel,
            accountId: popoverAccountId
        ) { [weak self] in
            self?.closePopover(for: popoverAccountId ?? setupSentinel)
        }
        let hostingController = NSHostingController(rootView: popoverView)
        let popover = NSPopover()
        popover.contentViewController = hostingController
        popover.behavior = .transient
        popover.animates = true

        return ManagedItem(statusItem: statusItem, popover: popover)
    }

    // MARK: - Icon updates

    private func updateIcon(for account: ClaudeAccount) {
        guard let item = managedItems[account.id], let button = item.statusItem.button else { return }

        let state = appModel.state(for: account.id)
        let percentage = clamped(state.usageData?.sessionUsage.percentage ?? 0)
        let weeklyPercentage = clamped(state.usageData?.weeklyUsage.percentage ?? 0)
        let status = state.usageData?.primaryStatus ?? .safe
        let isStale = state.usageData?.isStale ?? false
        let isLoading = state.isLoading
        let style = appModel.settings.iconStyle
        // Only show a label when more than one account is configured — single-account looks cleaner without it.
        let label: String? = appModel.settings.accounts.count > 1 ? account.menuBarInitial : nil

        if let cached = iconCache.get(
            percentage: percentage,
            status: status,
            isLoading: isLoading,
            isStale: isStale,
            iconStyle: style,
            weeklyPercentage: weeklyPercentage,
            accountLabel: label
        ) {
            button.image = cached
            return
        }

        let image = iconRenderer.render(
            percentage: percentage,
            status: status,
            isLoading: isLoading,
            isStale: isStale,
            iconStyle: style,
            weeklyPercentage: weeklyPercentage,
            accountLabel: label
        )

        iconCache.set(
            image,
            percentage: percentage,
            status: status,
            isLoading: isLoading,
            isStale: isStale,
            iconStyle: style,
            weeklyPercentage: weeklyPercentage,
            accountLabel: label
        )

        button.image = image
        button.setAccessibilityLabel("\(account.label): \(Int(percentage))%")
    }

    private func updateSetupItemIcon() {
        guard let item = managedItems[setupSentinel], let button = item.statusItem.button else { return }
        let symbol = NSImage(systemSymbolName: "gauge.with.dots.needle.0percent", accessibilityDescription: "ClaudeMeter setup")
        symbol?.isTemplate = true
        button.image = symbol
        button.setAccessibilityLabel("ClaudeMeter — setup required")
    }

    private func clamped(_ value: Double) -> Double {
        max(0, min(value, 100))
    }

    // MARK: - Popover control

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let identifier = sender.identifier?.rawValue,
              let id = UUID(uuidString: identifier) else { return }
        togglePopover(for: id)
    }

    private func togglePopover(for id: UUID) {
        guard let item = managedItems[id] else { return }
        if item.popover.isShown {
            item.popover.performClose(nil)
        } else {
            // Close any other open popover first.
            for (otherId, other) in managedItems where otherId != id && other.popover.isShown {
                other.popover.performClose(nil)
            }
            guard let button = item.statusItem.button else { return }
            item.popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func closePopover(for id: UUID) {
        managedItems[id]?.popover.performClose(nil)
    }

    private func showFirstPopover() {
        // Used when a notification asks us to surface the UI.
        if let firstAccount = appModel.settings.accounts.first,
           let item = managedItems[firstAccount.id] {
            guard let button = item.statusItem.button, !item.popover.isShown else { return }
            item.popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        } else if let setup = managedItems[setupSentinel] {
            guard let button = setup.statusItem.button, !setup.popover.isShown else { return }
            setup.popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
