import SwiftUI

struct UnlockView: View {
    @Environment(DatabaseManager.self) private var vault

    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPasswordField = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let unlockReason = "Unlock your GravieCopy clipboard vault"

    var body: some View {
        VStack(spacing: 20) {
            if !vault.hasExistingVault {
                setupView
            } else if showPasswordField {
                passwordUnlockView
            } else {
                biometricUnlockView
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(24)
        .task {
            // Auto-trigger Touch ID for returning users.
            if vault.hasExistingVault && KeychainService.hasStoredKey() {
                await tryBiometricUnlock()
            }
        }
    }

    // MARK: - Sub-views

    private var setupView: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 44))
                .foregroundStyle(.blue)

            Text("Create Your Vault")
                .font(.headline)

            Text("Set a master password to encrypt your clipboard history. You won't need to type it again — Touch ID will unlock the vault automatically.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            SecureField("Master Password (8+ characters)", text: $password)
                .textFieldStyle(.roundedBorder)

            SecureField("Confirm Password", text: $confirmPassword)
                .textFieldStyle(.roundedBorder)
                .onSubmit { Task { await setupVault() } }

            Button(action: { Task { await setupVault() } }) {
                loadingLabel("Create Vault")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isSetupValid || isLoading)
            .controlSize(.large)
        }
    }

    private var biometricUnlockView: some View {
        VStack(spacing: 14) {
            Image(systemName: "touchid")
                .font(.system(size: 44))
                .foregroundStyle(.blue)

            Text("Unlock GravieCopy")
                .font(.headline)

            Button(action: { Task { await tryBiometricUnlock() } }) {
                loadingLabel("Unlock with Touch ID")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading)
            .controlSize(.large)

            Button("Use Password Instead") {
                errorMessage = nil
                showPasswordField = true
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .font(.caption)
        }
    }

    private var passwordUnlockView: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.fill")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)

            Text("Enter Master Password")
                .font(.headline)

            SecureField("Master Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .onSubmit { Task { await unlockWithPassword() } }

            Button(action: { Task { await unlockWithPassword() } }) {
                loadingLabel("Unlock")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(password.isEmpty || isLoading)
            .controlSize(.large)

            if KeychainService.isTouchIDAvailable() {
                Button("Use Touch ID Instead") {
                    errorMessage = nil
                    password = ""
                    showPasswordField = false
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.caption)
            }
        }
    }

    // MARK: - Actions

    private func setupVault() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let salt = try vault.loadOrCreateSalt()
            let key = try await deriveKey(from: password, salt: salt)
            try vault.unlock(withKey: key)
            try? KeychainService.save(key)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func tryBiometricUnlock() async {
        guard KeychainService.isTouchIDAvailable() else {
            showPasswordField = true
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let key = try await KeychainService.load(reason: unlockReason)
            try vault.unlock(withKey: key)
        } catch {
            showPasswordField = true
            errorMessage = "Touch ID failed. Enter your master password."
        }
    }

    private func unlockWithPassword() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let salt = try vault.loadOrCreateSalt()
            let key = try await deriveKey(from: password, salt: salt)
            try vault.unlock(withKey: key)
            // Re-store in Keychain so Touch ID works next time.
            try? KeychainService.save(key)
        } catch {
            errorMessage = "Incorrect password or vault error."
        }
    }

    // MARK: - Helpers

    private var isSetupValid: Bool {
        password.count >= 8 && password == confirmPassword
    }

    /// Runs PBKDF2 off the main actor to avoid blocking the UI.
    private func deriveKey(from password: String, salt: Data) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            try KeyDerivationService.deriveKey(from: password, salt: salt)
        }.value
    }

    @ViewBuilder
    private func loadingLabel(_ title: String) -> some View {
        if isLoading {
            ProgressView().controlSize(.small)
        } else {
            Text(title)
        }
    }
}
