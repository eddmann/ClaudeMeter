//
//  SetupWizardView.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-14.
//

import SwiftUI
import AppKit

/// Setup wizard view used for the very first account, and for adding additional accounts.
struct SetupWizardView: View {
    @Bindable var appModel: AppModel
    /// Called when the wizard finishes successfully (used to dismiss the popover/sheet).
    var onComplete: (() -> Void)? = nil

    @State private var labelInput: String = ""
    @State private var sessionKeyInput: String = ""
    @State private var isValidating: Bool = false
    @State private var errorMessage: String?
    @State private var hasValidationSucceeded: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                if let appIcon = NSImage(named: NSImage.applicationIconName) {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 64, height: 64)
                } else {
                    Image(systemName: "gauge.with.dots.needle.67percent")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                }

                Text(appModel.settings.accounts.isEmpty ? "Welcome to ClaudeMeter" : "Add Another Account")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Monitor your Claude.ai plan usage in real-time")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 32)

            VStack(alignment: .leading, spacing: 8) {
                Text("Account Label")
                    .font(.headline)

                TextField("e.g. Personal, Client X", text: $labelInput)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isValidating)
                    .accessibilityLabel("Account label")

                Text("Used to distinguish this account in the menu bar")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 32)

            VStack(alignment: .leading, spacing: 8) {
                Text("Claude Session Key")
                    .font(.headline)

                SecureField("sk-ant-...", text: $sessionKeyInput)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isValidating)
                    .accessibilityLabel("Session key input field")

                Text("Find your session key in Claude.ai browser cookies")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if !sessionKeyInput.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: isFormatValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(isFormatValid ? .green : .red)
                        Text(isFormatValid ? "Format valid" : "Invalid format (must start with sk-ant-)")
                            .font(.caption)
                            .foregroundColor(isFormatValid ? .green : .red)
                    }
                }
            }
            .padding(.horizontal, 32)

            if let errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundColor(.orange)
                }
                .padding(12)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal, 32)
                .accessibilityLabel("Error: \(errorMessage)")
            }

            if hasValidationSucceeded {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Account added!")
                        .font(.callout)
                        .foregroundColor(.green)
                }
                .padding(12)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal, 32)
            }

            Spacer()

            Button(action: {
                Task { await validateAndSave() }
            }) {
                HStack {
                    Text(isValidating ? "Validating..." : "Continue")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .allowsHitTesting(isFormatValid && !isValidating)
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
            .accessibilityLabel(isValidating ? "Validating session key" : "Continue with setup")
        }
        .frame(width: 360, height: 460)
    }

    // MARK: - Validation

    private var isFormatValid: Bool {
        let trimmed = sessionKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("sk-ant-") && trimmed.count > 10
    }

    @MainActor
    private func validateAndSave() async {
        guard !sessionKeyInput.isEmpty else {
            errorMessage = "Session key cannot be empty"
            hasValidationSucceeded = false
            return
        }

        isValidating = true
        errorMessage = nil
        hasValidationSucceeded = false

        do {
            let resolvedLabel = labelInput.trimmingCharacters(in: .whitespacesAndNewlines)
            let account = try await appModel.addAccount(label: resolvedLabel, sessionKey: sessionKeyInput)
            if account != nil {
                hasValidationSucceeded = true
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(800))
                    onComplete?()
                }
            } else {
                errorMessage = "Session key is invalid or expired"
            }
        } catch let error as SessionKeyError {
            errorMessage = error.localizedDescription
        } catch let error as NetworkError {
            errorMessage = "Network error: \(error.localizedDescription)"
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Validation failed: \(error.localizedDescription)"
        }

        isValidating = false
    }
}
