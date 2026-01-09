//
//  SetupWizardView.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-14.
//

import SwiftUI
import AppKit

/// Setup wizard view for initial configuration
struct SetupWizardView: View {
    @Bindable var appModel: AppModel

    @State private var sessionKeyInput: String = ""
    @State private var isValidating: Bool = false
    @State private var errorMessage: String?
    @State private var hasValidationSucceeded: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            // Header
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

                Text("Welcome to ClaudeMeter")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Monitor your Claude.ai plan usage in real-time")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 32)

            // Session Key Input
            VStack(alignment: .leading, spacing: 8) {
                Text("Claude Session Key")
                    .font(.headline)

                SecureField("sk-ant-...", text: $sessionKeyInput)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isValidating)
                    .accessibilityLabel("Session key input field")
                    .accessibilityHint("Enter your Claude session key starting with sk-ant-")

                Text("Find your session key in Claude.ai browser cookies")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Format validation indicator
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

            // Error Message
            if let errorMessage = errorMessage {
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

            // Success Message
            if hasValidationSucceeded {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Setup complete! Launching ClaudeMeter...")
                        .font(.callout)
                        .foregroundColor(.green)
                }
                .padding(12)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal, 32)
            }

            Spacer()

            // Continue Button
            Button(action: {
                Task {
                    await validateAndSave()
                }
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
            .accessibilityHint("Validates your session key and completes setup")
        }
        .frame(width: 360, height: 420)
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
            let isValid = try await appModel.validateAndSaveSessionKey(sessionKeyInput)
            if isValid {
                hasValidationSucceeded = true
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
