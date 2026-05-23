import Foundation

struct AppBlacklist {
    private static let userDefaultsKey = "customBlacklistedApps"

    // Password managers and sensitive apps ignored by default.
    static let defaults: Set<String> = [
        "com.agilebits.onepassword-osx",
        "com.agilebits.onepassword7",
        "com.agilebits.onepassword8",
        "com.bitwarden.desktop",
        "com.lastpass.LastPass",
        "com.apple.keychainaccess",
        "com.apple.SecurityAgent",
        "us.zoom.xos",                  // Zoom (screen-share risk)
    ]

    static var custom: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: userDefaultsKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: userDefaultsKey) }
    }

    static func contains(_ bundleID: String) -> Bool {
        !bundleID.isEmpty && (defaults.contains(bundleID) || custom.contains(bundleID))
    }
}
