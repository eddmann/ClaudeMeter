//
//  MenuBarManager.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-14.
//

import AppKit
import SwiftUI
import Combine

/// Manages NSStatusBar and popover
@MainActor
final class MenuBarManager: ObservableObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let iconCache = IconCache()
    private let iconRenderer = MenuBarIconRenderer()

    private let container: DIContainer
    private var viewModel: MenuBarViewModel?
    private var cancellables = Set<AnyCancellable>()

    /// Current icon style (from settings)
    private var iconStyle: IconStyle = .battery
    /// Preview icon style (for live settings preview, nil when not previewing)
    private var previewIconStyle: IconStyle?
    /// Effective icon style to use for rendering
    private var effectiveIconStyle: IconStyle {
        previewIconStyle ?? iconStyle
    }

    init(container: DIContainer) {
        self.container = container
    }

    /// Setup menu bar status item and popover
    func setupMenuBar() async {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem?.button else { return }

        // Load initial icon style from settings
        let settings = await container.settingsRepository.load()
        iconStyle = settings.iconStyle

        let vm = MenuBarViewModel(
            usageService: container.usageService,
            settingsRepository: container.settingsRepository,
            notificationService: container.notificationService
        )
        self.viewModel = vm

        // Observe usage data changes to update icon
        vm.$usageData
            .combineLatest(vm.$isLoading)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] usageData, isLoading in
                self?.updateIcon(usageData: usageData, isLoading: isLoading, button: button)
            }
            .store(in: &cancellables)

        button.action = #selector(togglePopover)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        // Setup popover
        createPopover()

        // Setup notification observer for opening popover
        NotificationCenter.default.publisher(for: .openUsagePopover)
            .sink { [weak self] _ in
                self?.showPopover()
            }
            .store(in: &cancellables)

        // Setup observer for icon style preview (live preview in settings)
        NotificationCenter.default.publisher(for: .iconStylePreviewChanged)
            .sink { [weak self] notification in
                guard let self = self else { return }
                if let style = notification.object as? IconStyle {
                    // Preview a specific style
                    self.previewIconStyle = style
                } else {
                    // nil means revert - reload saved style from settings to ensure consistency
                    Task { @MainActor in
                        let settings = await self.container.settingsRepository.load()
                        self.iconStyle = settings.iconStyle
                        self.previewIconStyle = nil
                        if let button = self.statusItem?.button {
                            self.updateIcon(usageData: self.viewModel?.usageData, isLoading: self.viewModel?.isLoading ?? false, button: button)
                        }
                    }
                    return
                }
                if let button = self.statusItem?.button {
                    self.updateIcon(usageData: self.viewModel?.usageData, isLoading: self.viewModel?.isLoading ?? false, button: button)
                }
            }
            .store(in: &cancellables)

        // Setup observer for settings changes (persisted icon style)
        NotificationCenter.default.publisher(for: .settingsDidChange)
            .sink { [weak self] _ in
                Task { @MainActor in
                    guard let self = self else { return }
                    let settings = await self.container.settingsRepository.load()
                    self.iconStyle = settings.iconStyle
                    self.previewIconStyle = nil // Clear preview on save
                    if let button = self.statusItem?.button {
                        self.updateIcon(usageData: self.viewModel?.usageData, isLoading: self.viewModel?.isLoading ?? false, button: button)
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Private Methods

    private func updateIcon(usageData: UsageData?, isLoading: Bool, button: NSButton) {
        let percentage = usageData?.sessionUsage.percentage ?? 0
        let weeklyPercentage = usageData?.weeklyUsage.percentage ?? 0
        let status = usageData?.primaryStatus ?? .safe
        let isStale = usageData?.isStale ?? false
        let style = effectiveIconStyle

        if let cachedImage = iconCache.get(
            percentage: percentage,
            status: status,
            isLoading: isLoading,
            isStale: isStale,
            iconStyle: style,
            weeklyPercentage: weeklyPercentage
        ) {
            button.image = cachedImage
            return
        }

        let image = iconRenderer.render(
            percentage: percentage,
            status: status,
            isLoading: isLoading,
            isStale: isStale,
            iconStyle: style,
            weeklyPercentage: weeklyPercentage
        )

        iconCache.set(
            image,
            percentage: percentage,
            status: status,
            isLoading: isLoading,
            isStale: isStale,
            iconStyle: style,
            weeklyPercentage: weeklyPercentage
        )

        button.image = image
    }

    private func createPopover() {
        guard let vm = viewModel else { return }

        let popoverViewModel = UsagePopoverViewModel(
            usageService: container.usageService,
            settingsRepository: container.settingsRepository
        )

        // Share usage data from menu bar view model
        vm.$usageData
            .assign(to: &popoverViewModel.$usageData)

        let popoverView = UsagePopoverView(viewModel: popoverViewModel)
        let hostingController = NSHostingController(rootView: popoverView)

        // Configure popover
        let newPopover = NSPopover()
        newPopover.contentViewController = hostingController
        newPopover.behavior = .transient // Dismiss when clicking outside
        newPopover.contentSize = NSSize(width: 320, height: 400)

        self.popover = newPopover
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }

        if let popover = popover, popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem?.button, let popover = popover else { return }

        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Activate app to ensure popover is frontmost
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
