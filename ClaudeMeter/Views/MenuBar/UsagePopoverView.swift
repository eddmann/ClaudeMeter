//
//  UsagePopoverView.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-14.
//

import SwiftUI
import AppKit

/// Usage popover view for a single Claude account.
struct UsagePopoverView: View {
    @Bindable var appModel: AppModel
    let account: ClaudeAccount
    let onRequestClose: (() -> Void)?
    @Environment(\.openSettings) private var openSettings

    private var state: AccountUsageState {
        appModel.state(for: account.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if let errorMessage = state.errorMessage {
                errorBanner(errorMessage)
                Divider()
            }

            content

            Divider()

            footer
        }
        .frame(width: 320, height: 460)
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Usage Dashboard for \(account.label)")
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(account.label)
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Claude Usage")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: {
                Task { await appModel.refreshUsage(accountId: account.id, forceRefresh: true) }
            }) {
                if state.isRefreshing {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .buttonStyle(.plain)
            .disabled(state.isRefreshing)
            .help("Refresh usage data")
            .keyboardShortcut("r", modifiers: .command)
        }
        .padding()
    }

    private func errorBanner(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(message)
                    .font(.callout)
                    .foregroundColor(.primary)
                Spacer()
            }

            HStack(spacing: 8) {
                Button("Retry") {
                    Task { await appModel.refreshUsage(accountId: account.id, forceRefresh: true) }
                }
                .buttonStyle(.bordered)

                if message.contains("invalid") || message.contains("expired") || message.contains("authentication") {
                    Button("Update Session Key") {
                        openSettingsFront()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
    }

    @ViewBuilder
    private var content: some View {
        if let usageData = state.usageData {
            ScrollView {
                VStack(spacing: 16) {
                    UsageCardView(
                        title: "5-Hour Session",
                        usageLimit: usageData.sessionUsage,
                        icon: "gauge.with.dots.needle.67percent",
                        windowDuration: Constants.Pacing.sessionWindow
                    )
                    UsageCardView(
                        title: "Weekly Usage",
                        usageLimit: usageData.weeklyUsage,
                        icon: "calendar",
                        windowDuration: Constants.Pacing.weeklyWindow
                    )
                    if appModel.settings.isSonnetUsageShown, let sonnetUsage = usageData.sonnetUsage {
                        UsageCardView(
                            title: "Weekly Sonnet",
                            usageLimit: sonnetUsage,
                            icon: "sparkles",
                            windowDuration: Constants.Pacing.weeklyWindow
                        )
                    }
                }
                .padding()
            }
        } else {
            VStack(spacing: 16) {
                ProgressView()
                Text("Loading usage data...")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
    }

    private var footer: some View {
        HStack {
            Button("Settings") {
                openSettingsFront()
            }
            .buttonStyle(.plain)
            .keyboardShortcut(",", modifiers: .command)
            .accessibilityLabel("Open settings window")

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q", modifiers: .command)
            .accessibilityLabel("Quit application")
        }
        .padding()
    }

    private func openSettingsFront() {
        onRequestClose?()
        if let keyWindow = NSApp.keyWindow, keyWindow.level != .normal {
            keyWindow.orderOut(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
        openSettings()
    }
}
