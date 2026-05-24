import Foundation
import GRDB
import Observation

enum VaultError: LocalizedError {
    case locked
    case saltCorrupted
    case migrationFailed(Error)

    var errorDescription: String? {
        switch self {
        case .locked: "The vault is locked. Unlock it before performing database operations."
        case .saltCorrupted: "The vault salt file is corrupted and cannot be read."
        case .migrationFailed(let error): "Database migration failed: \(error.localizedDescription)"
        }
    }
}

@Observable
@MainActor
final class DatabaseManager {
    static let shared = DatabaseManager()

    private(set) var isLocked = true
    private(set) var repository: ClipboardRepository?
    // Stored so @Observable notifies SwiftUI when the vault is created or wiped.
    private(set) var vaultExists: Bool

    private var dbQueue: DatabaseQueue?
    private var autoLockTask: Task<Void, Never>?

    var autoLockInterval: TimeInterval = 15 * 60

    // MARK: - Init

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let salt = appSupport
            .appendingPathComponent("GravieCopy")
            .appendingPathComponent("vault.salt")
        vaultExists = FileManager.default.fileExists(atPath: salt.path)
    }

    // MARK: - Paths

    private let vaultDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("GravieCopy", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private var dbURL: URL { vaultDirectory.appendingPathComponent("vault.db") }
    private var saltURL: URL { vaultDirectory.appendingPathComponent("vault.salt") }

    // MARK: - Vault state

    var hasExistingVault: Bool { vaultExists }

    // MARK: - Salt

    func loadOrCreateSalt() throws -> Data {
        if FileManager.default.fileExists(atPath: saltURL.path) {
            guard let salt = try? Data(contentsOf: saltURL), salt.count == KeyDerivationService.saltLength else {
                throw VaultError.saltCorrupted
            }
            return salt
        }

        let salt = KeyDerivationService.generateSalt()
        try salt.write(to: saltURL, options: .atomic)
        vaultExists = true

        // Exclude the salt file from iCloud backups.
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var mutableURL = saltURL
        try? mutableURL.setResourceValues(resourceValues)

        return salt
    }

    // MARK: - Unlock / Lock

    func unlock(withKey key: Data) throws {
        let hexKey = key.map { String(format: "%02x", $0) }.joined()

        var config = Configuration()
        // Pass derived key in SQLCipher raw-key format to skip its internal PBKDF.
        config.prepareDatabase { db in
            try db.usePassphrase("x'\(hexKey)'")
        }

        let queue = try DatabaseQueue(path: dbURL.path, configuration: config)
        try runMigrations(on: queue)

        dbQueue = queue
        repository = ClipboardRepository(db: queue)
        isLocked = false

        // Apply the persisted auto-lock setting before arming the timer.
        autoLockInterval = SettingsStore.shared.autoLockInterval
        scheduleAutoLock()
        runRetentionPurge()
    }

    func lock() {
        autoLockTask?.cancel()
        autoLockTask = nil
        repository = nil
        dbQueue = nil
        isLocked = true
    }

    /// Irreversibly destroys the encrypted vault (DB + salt) and Keychain entry.
    /// Called after too many failed password attempts.
    func wipeVault() {
        lock()
        try? FileManager.default.removeItem(at: dbURL)
        try? FileManager.default.removeItem(at: saltURL)
        KeychainService.delete()
        vaultExists = false
    }

    // MARK: - Auto-Lock

    func resetAutoLockTimer() {
        guard !isLocked else { return }
        scheduleAutoLock()
    }

    private func scheduleAutoLock() {
        autoLockTask?.cancel()
        guard autoLockInterval > 0 else { return } // 0 = never lock
        let interval = autoLockInterval
        autoLockTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(interval))
            guard !Task.isCancelled else { return }
            await self?.lock()
        }
    }

    // MARK: - Retention

    func runRetentionPurge() {
        let period = SettingsStore.shared.retentionPeriod
        guard period > 0, let repo = repository else { return }
        let cutoff = Date().addingTimeInterval(-period)
        try? repo.deleteExpired(before: cutoff)
    }

    // MARK: - Migrations

    private func runMigrations(on queue: DatabaseQueue) throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_initial_schema") { db in
            try db.create(table: "clipboard_items") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("contentType", .text).notNull()
                t.column("rawData", .blob).notNull()
                t.column("createdAt", .datetime).notNull()
                t.column("isPinned", .boolean).notNull().defaults(to: false)
                t.column("sourceApp", .text)
                t.column("contentHash", .text).notNull()
            }
            try db.create(
                index: "clipboard_items_on_contentHash",
                on: "clipboard_items",
                columns: ["contentHash"],
                unique: true
            )
            try db.create(
                index: "clipboard_items_on_createdAt",
                on: "clipboard_items",
                columns: ["createdAt"]
            )
        }

        do {
            try migrator.migrate(queue)
        } catch {
            throw VaultError.migrationFailed(error)
        }
    }
}
