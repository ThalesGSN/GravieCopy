# Product Requirements Document (PRD): Secure Health-Data Clipboard Manager

## 1. Product Overview
A secure, native macOS clipboard manager designed specifically to handle sensitive healthcare data (LGPD/HIPAA compliant). The application operates entirely locally, utilizing encrypted storage, zero telemetry, and strict access controls to prevent data leaks.

## 2. Technical Stack
*   **Platform:** Native macOS
*   **UI Framework:** SwiftUI (Menu Bar App or floating `NSPanel`)
*   **Database:** SQLite via `GRDB.swift`
*   **Encryption Engine:** SQLCipher (bundled with GRDB)
*   **Cryptography & Auth:** CryptoKit, LocalAuthentication (Touch ID / Secure Enclave), Swift-Sodium (for Argon2) or PBKDF2.

## 3. Security & Privacy Core
*   **Air-Gapped Architecture:** The app manifesto must request NO network permissions. Zero telemetry, crash reporting, or external data transmission.
*   **Encryption at Rest:** All locally stored clipboard history must be encrypted using AES-256 (via SQLCipher). No plaintext data should ever touch the disk.
*   **Master Password Derivation:** The master password is never stored. It is passed through a key derivation function (Argon2/PBKDF2) alongside a Salt to generate the encryption key.
*   **Biometric Unlock:** Integration with macOS Touch ID to decrypt the vault using the system's Keychain and Secure Enclave, replacing the need to type the master password repeatedly.
*   **Auto-Lock Mechanism:** The vault automatically locks (drops the database connection and securely clears variables from memory) after a configurable period of inactivity or upon OS sleep/screen lock events.
*   **Ephemeral Retention (Data Purge):** Automated routine to securely delete copied data older than a configurable threshold (e.g., 24 hours).
*   **Sensitive App Blacklist:** Automatically ignores clipboard changes when the currently focused application (`NSWorkspace.shared.frontmostApplication?.bundleIdentifier`) is on a blacklist (e.g., 1Password, specific EHR/EMR systems).

## 4. Clipboard Management Capabilities
*   **Data Type Support:** Intercept and store Plain Text, Rich Text (RTF), and Images (useful for charts and medical images).
*   **In-Memory Search:** Fast, full-text search executed entirely in RAM while the vault is unlocked.
*   **Pinned Items:** Ability to save and pin frequent health templates (e.g., standard clinical note headers) that are exempt from the ephemeral retention purge.
*   **Format Sanitization:** Option to strip rich formatting and paste strictly as plain text.

## 5. macOS Native Integration & UX
*   **Passive Clipboard Monitoring:** Polling `NSPasteboard.general.changeCount` via a background thread timer (e.g., every 500ms) to avoid blocking the main thread and draining the battery.
*   **Global Hotkeys:** Registration of global keyboard shortcuts (e.g., via the `KeyboardShortcuts` library) to invoke the UI instantly over any active window.
*   **Keyboard-First Navigation:** 100% keyboard-accessible interface (arrow keys to search/navigate, `Enter` to select and paste).
*   **Automated Text Injection (Auto-Paste Flow):**
        1. Requires user-granted macOS Accessibility Permissions.
        2. Captures the previously active app using `NSWorkspace`.
        3. Updates `NSPasteboard.general` with the decrypted selected item.
        4. Hides the clipboard manager UI.
        5. Restores focus to the previous target application.
        6. Simulates a `Cmd + V` keystroke using `CGEvent` to securely inject the data without direct text field access.
