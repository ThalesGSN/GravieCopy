import Foundation
import Observation

@Observable
@MainActor
final class SettingsStore {
    static let shared = SettingsStore()
    private let ud = UserDefaults.standard

    // MARK: - Settings

    /// Seconds of inactivity before the vault auto-locks. 0 = never lock.
    var autoLockInterval: TimeInterval {
        didSet {
            ud.set(autoLockInterval, forKey: "autoLockInterval")
            let db = DatabaseManager.shared
            db.autoLockInterval = autoLockInterval
            db.resetAutoLockTimer()
        }
    }

    /// How long to keep unpinned items. 0 = keep forever.
    var retentionPeriod: TimeInterval {
        didSet { ud.set(retentionPeriod, forKey: "retentionPeriod") }
    }

    /// User-defined bundle IDs added to the capture blacklist.
    var customBlacklist: Set<String> {
        didSet { ud.set(Array(customBlacklist), forKey: "customBlacklistedApps") }
    }

    // MARK: - Init

    private init() {
        // Distinguish "never set" from an intentional 0 (Never/Forever) via
        // object(forKey:) — returns nil when the key is absent.
        if ud.object(forKey: "autoLockInterval") != nil {
            autoLockInterval = ud.double(forKey: "autoLockInterval")
        } else {
            autoLockInterval = 15 * 60  // default: 15 minutes
        }

        if ud.object(forKey: "retentionPeriod") != nil {
            retentionPeriod = ud.double(forKey: "retentionPeriod")
        } else {
            retentionPeriod = 24 * 3600  // default: 24 hours
        }

        customBlacklist = Set(ud.stringArray(forKey: "customBlacklistedApps") ?? [])
    }

    // MARK: - Picker options

    static let autoLockOptions: [(label: String, value: TimeInterval)] = [
        ("5 minutes",  5 * 60),
        ("15 minutes", 15 * 60),
        ("30 minutes", 30 * 60),
        ("1 hour",     3600),
        ("4 hours",    4 * 3600),
        ("Never",      0),
    ]

    static let retentionOptions: [(label: String, value: TimeInterval)] = [
        ("12 hours",     12 * 3600),
        ("24 hours",     24 * 3600),
        ("48 hours",     48 * 3600),
        ("7 days",       7 * 24 * 3600),
        ("Keep forever", 0),
    ]
}
