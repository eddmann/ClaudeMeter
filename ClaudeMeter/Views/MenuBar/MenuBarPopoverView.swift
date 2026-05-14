//
//  MenuBarPopoverView.swift
//  ClaudeMeter
//
//  Created by Edd on 2026-01-14.
//

import SwiftUI

/// Root view for a menu bar popover. When `account` is set the popover shows that account's usage;
/// otherwise the setup wizard is shown so the user can configure their first account.
struct MenuBarPopoverView: View {
    @Bindable var appModel: AppModel
    /// When nil, this popover hosts the setup wizard (no account configured yet).
    let accountId: UUID?
    let onRequestClose: () -> Void

    var body: some View {
        if let accountId, let account = appModel.settings.account(withId: accountId) {
            UsagePopoverView(
                appModel: appModel,
                account: account,
                onRequestClose: onRequestClose
            )
        } else {
            SetupWizardView(
                appModel: appModel,
                onComplete: onRequestClose
            )
        }
    }
}
