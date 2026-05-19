import SwiftUI
import AppKit

struct SetupWizardView: View {
    @Bindable var appModel: AppModel

    @State private var sessionKeyInput: String = ""
    @State private var isValidating: Bool = false
    @State private var isImporting: Bool = false
    @State private var errorMessage: String?
    @State private var offersFullDiskAccessSettings: Bool = false
    @State private var hasValidationSucceeded: Bool = false

    var body: some View {
        VStack(spacing: 22) {
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
                Text("Claude Session")
                    .font(.headline)

                SecureField("sk-ant-...", text: $sessionKeyInput)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isBusy)
                    .accessibilityLabel("Session key input field")
                    .accessibilityHint("Enter your Claude session key or paste a Cookie header containing sessionKey")

                Text("Import from a browser signed in to claude.ai, or paste your session")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Format validation indicator
                if !sessionKeyInput.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: isFormatValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(isFormatValid ? .green : .red)
                        Text(isFormatValid ? "Session format valid" : "Invalid session format")
                            .font(.caption)
                            .foregroundColor(isFormatValid ? .green : .red)
                    }
                }
            }
            .padding(.horizontal, 32)

            // Error Message
            if let errorMessage = errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .frame(width: 20)
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundColor(.orange)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if offersFullDiskAccessSettings {
                        Button("Open Full Disk Access") {
                            SystemSettingsOpener.openFullDiskAccess()
                        }
                        .controlSize(.small)
                        .padding(.leading, 28)
                    }
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

            // Actions
            VStack(spacing: 8) {
                Button(action: {
                    Task {
                        await importAndSave()
                    }
                }) {
                    HStack {
                        if isImporting {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(isImporting ? "Importing..." : "Import from Browser")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isBusy)
                .accessibilityLabel(isImporting ? "Importing session key" : "Import session key from browser")
                .accessibilityHint("Finds your Claude session key in local browser cookies and validates it")

                Button(action: {
                    Task {
                        await validateAndSave()
                    }
                }) {
                    HStack {
                        Text(isValidating ? "Validating..." : "Continue Manually")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .disabled(!isFormatValid || isBusy)
                .accessibilityLabel(isValidating ? "Validating session key" : "Continue with manual setup")
                .accessibilityHint("Validates your session key and completes setup")
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .frame(width: 370, height: 460)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    // MARK: - Validation

    private var isBusy: Bool {
        isValidating || isImporting
    }

    private var isFormatValid: Bool {
        let trimmed = sessionKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = SessionKey.extractSessionKeyValue(from: trimmed) else { return false }
        return value.hasPrefix("sk-ant-") && value.count > 10
    }

    @MainActor
    private func importAndSave() async {
        isImporting = true
        errorMessage = nil
        offersFullDiskAccessSettings = false
        hasValidationSucceeded = false

        do {
            let imported = try await appModel.importAndSaveSessionKey()
            sessionKeyInput = imported.value
            hasValidationSucceeded = true
        } catch let error as SessionKeyImportError {
            errorMessage = error.localizedDescription
            offersFullDiskAccessSettings = error.offersFullDiskAccessSettings
        } catch let error as NetworkError {
            errorMessage = "Network error: \(error.localizedDescription)"
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Import failed: \(error.localizedDescription)"
        }

        isImporting = false
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
        offersFullDiskAccessSettings = false
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
