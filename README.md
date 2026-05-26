# GravieCopy

A secure, native macOS clipboard manager built for handling sensitive healthcare data. Designed for LGPD/HIPAA-conscious workflows — everything stays local, nothing leaves the device.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 6](https://img.shields.io/badge/Swift-6.0-orange)
![License](https://img.shields.io/badge/license-MIT-green)

---

## Features

- **AES-256 encrypted vault** — clipboard history stored in SQLCipher-encrypted SQLite; no plaintext ever hits the disk
- **Touch ID unlock** — derived key stored in Keychain with biometric access control; no password typing after first setup
- **PBKDF2-SHA256 key derivation** — 100k iterations; master password is never stored
- **Brute-force protection** — 3 consecutive wrong passwords trigger progressive lockouts (2 min, then 5 min); third failure wipes the vault; counter survives force-quit (persisted in UserDefaults)
- **Auto-lock** — vault locks automatically after configurable inactivity (5 min → 4 h)
- **Launch at Login** — optional auto-start via `SMAppService`; prompts to approve in System Settings if required
- **Ephemeral retention** — unpinned items auto-purged after a configurable window (12 h → 1 month)
- **App blacklist** — ignores clipboard changes when password managers or other sensitive apps are in focus
- **Global hotkey** — `Cmd+Shift+V` opens the panel over any active window (Carbon `RegisterEventHotKey`, no extra permissions)
- **Right-click menu** — right-click the menu bar icon for About, Settings, and Quit without opening the main panel
- **Auto-paste** — selects an item, restores focus to your previous app, and injects `Cmd+V` via `CGEvent`
- **In-memory search** — full-text search runs entirely in RAM on decrypted content
- **Pinned items** — pin frequently used templates; they survive the retention purge
- **Plain-text strip** — paste RTF content as plain text with one toggle
- **Zero telemetry** — no network permissions, no crash reporting, no analytics
- **Supports** plain text, RTF, and images

---

## Requirements

- macOS 14 Sonoma or later
- Xcode 16+
- CocoaPods (`gem install cocoapods`)

---

## Setup

```bash
git clone https://github.com/ThalesGSN/GravieCopy.git
cd GravieCopy
pod install
open GravieCopy.xcworkspace
```

Build and run with `Cmd+R` in Xcode. The app installs as a menu bar icon with no Dock entry.

> **First launch:** you'll be prompted to create a master password. This derives the AES-256 key via PBKDF2 and stores it in your Keychain behind Touch ID for subsequent unlocks.

---

## Architecture

```
GravieCopy/
├── Database/
│   ├── ClipboardItem.swift          # GRDB record — nonisolated conformances for Swift 6
│   ├── ClipboardRepository.swift    # Read/write/search/purge operations
│   ├── DatabaseManager.swift        # Encrypted DatabaseQueue lifecycle, auto-lock, migrations
│   └── KeyDerivationService.swift   # PBKDF2-SHA256 via CommonCrypto
├── Services/
│   ├── AppBlacklist.swift           # Default + user-defined bundle ID blacklist
│   ├── AutoPasteService.swift       # Focus capture, CGEvent Cmd+V injection
│   ├── ClipboardMonitor.swift       # 500 ms NSPasteboard polling
│   ├── HotkeyManager.swift          # Global hotkey via Carbon RegisterEventHotKey
│   ├── KeychainService.swift        # Touch ID + Keychain (SecAccessControl .userPresence)
│   └── SettingsStore.swift          # @Observable settings backed by UserDefaults
├── Views/
│   ├── ClipboardItemRow.swift       # Adaptive row: text / RTF preview / image thumbnail
│   ├── ClipboardListView.swift      # Search, keyboard nav, paste action
│   ├── MenuBarContentView.swift     # Vault gate: UnlockView ↔ ClipboardListView
│   ├── SettingsView.swift           # Auto-lock, retention, blacklist editor
│   └── UnlockView.swift             # Setup / Touch ID / password fallback
├── AppDelegate.swift                # NSStatusItem + NSPopover, hotkey wiring
└── GravieCopyApp.swift              # @main, Settings scene
```

### Security model

| Layer | Mechanism |
|---|---|
| Encryption at rest | SQLCipher AES-256 (raw key, bypasses SQLCipher's own KDF) |
| Key derivation | PBKDF2-SHA256, 100k iterations, 32-byte salt (excluded from iCloud) |
| Key storage | Keychain `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` + `.userPresence` |
| Auto-lock | Cancellable `Task.sleep`; also locks on idle timeout |
| Capture blacklist | Checked against `NSWorkspace.frontmostApplication.bundleIdentifier` on every poll |
| Network | None — `com.apple.security.network.client` entitlement is absent |

---

## Dependencies

Managed via [CocoaPods](https://cocoapods.org):

| Pod | Purpose |
|---|---|
| [GRDB.swift/SQLCipher](https://github.com/groue/GRDB.swift) | SQLite ORM + SQLCipher encryption |

---

## Settings

Open **Settings** (`Cmd+,` or right-click the menu bar icon → **Settings…**):

**General**
- **Launch at Login** — toggle auto-start; if system approval is needed a prompt links directly to System Settings › Login Items
- **Auto-lock after** — 5 min / 15 min / 30 min / 1 h / 4 h (default: 1 h)
- **Retain history for** — 12 h / 24 h / 48 h / 7 days / 1 month

**Blocked Apps**
- Add bundle IDs manually or pick from the currently running apps menu; built-in defaults include 1Password, Bitwarden, LastPass, Zoom

**Data**
- **Clear History** — permanently deletes all unpinned clipboard items (vault and settings intact)
- **Delete Vault** — destroys the encrypted database, salt file, and Keychain entry; requires fresh setup afterwards

---

## License

MIT
