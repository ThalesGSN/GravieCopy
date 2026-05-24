import SwiftUI

struct UnlockView: View {
    @Environment(DatabaseManager.self) private var vault
    private let throttle = BruteForceGuard.shared

    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPasswordField = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var lockoutSecondsRemaining = 0

    private let unlockReason = "Unlock your GravieCopy clipboard vault"

    var body: some View {
        VStack(spacing: 20) {
            if throttle.isLocked {
                lockoutView
            } else if !vault.vaultExists {
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
            if vault.vaultExists && KeychainService.hasStoredKey() {
                await tryBiometricUnlock()
            }
        }
        // Tick the lockout countdown every second while locked.
        .task(id: throttle.lockedUntil) {
            while !Task.isCancelled && throttle.isLocked {
                lockoutSecondsRemaining = throttle.remainingSeconds
                try? await Task.sleep(for: .seconds(1))
            }
            lockoutSecondsRemaining = 0
        }
    }

    // MARK: - Sub-views

    private var lockoutView: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)

            Text("Too Many Failed Attempts")
                .font(.headline)

            Text(formattedCountdown)
                .font(.system(size: 36, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())

            Text("Wait before trying again")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

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

            // Attempts-remaining warning
            if throttle.attemptsRemaining <= 2 && throttle.failedAttempts > 0 {
                attemptsWarning
            }

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

    private var attemptsWarning: some View {
        let remaining = throttle.attemptsRemaining
        let isLast = remaining == 1
        return HStack(spacing: 6) {
            Image(systemName: isLast ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(isLast ? .red : .orange)
            Text(isLast
                 ? "Last attempt — vault will be wiped on failure"
                 : "\(remaining) attempts remaining")
                .font(.caption)
                .foregroundStyle(isLast ? .red : .orange)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill((isLast ? Color.red : Color.orange).opacity(0.1))
        )
    }

    // MARK: - Actions

    private func setupVault() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let salt = try vault.loadOrCreateSalt()
            let key  = try await deriveKey(from: password, salt: salt)
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
            throttle.recordSuccess()
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
            let key  = try await deriveKey(from: password, salt: salt)
            try vault.unlock(withKey: key)
            try? KeychainService.save(key)
            throttle.recordSuccess()
        } catch {
            password = ""
            switch throttle.recordFailure() {
            case .vaultWiped:
                vault.wipeVault()
                errorMessage = "Too many failed attempts — vault has been permanently wiped."
            case .lockedOut(let seconds):
                let mins = seconds / 60
                errorMessage = "Incorrect password. Locked for \(mins) minute\(mins == 1 ? "" : "s")."
                lockoutSecondsRemaining = throttle.remainingSeconds
            }
        }
    }

    // MARK: - Helpers

    private var isSetupValid: Bool {
        password.count >= 8 && password == confirmPassword
    }

    private var formattedCountdown: String {
        let s = lockoutSecondsRemaining
        return String(format: "%d:%02d", s / 60, s % 60)
    }

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
