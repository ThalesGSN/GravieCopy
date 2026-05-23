import Foundation
import Security
import LocalAuthentication

struct KeychainService {
    private static let service = "us.gravie.GravieCopy.vault"
    private static let account = "derivedKey"

    // MARK: - Public API

    /// Stores the derived key in the Keychain, protected by Touch ID or device passcode.
    static func save(_ key: Data) throws {
        var cfError: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .userPresence,
            &cfError
        ) else {
            throw KeychainError.accessControlFailed
        }

        delete() // Clear any stale entry before writing.

        let attrs: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: key,
            kSecAttrAccessControl: access,
            kSecUseDataProtectionKeychain: true,
        ]

        let status = SecItemAdd(attrs as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    /// Authenticates via Touch ID and returns the stored derived key.
    /// The LAContext is created, used, and released entirely within the callback
    /// to avoid sending a non-Sendable reference across actor boundaries.
    static func load(reason: String) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            let context = LAContext()
            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            ) { success, error in
                guard success else {
                    continuation.resume(throwing: error ?? KeychainError.loadFailed(errSecAuthFailed))
                    return
                }

                let query: [CFString: Any] = [
                    kSecClass: kSecClassGenericPassword,
                    kSecAttrService: service,
                    kSecAttrAccount: account,
                    kSecReturnData: true,
                    kSecUseAuthenticationContext: context,
                    kSecUseDataProtectionKeychain: true,
                ]

                var result: CFTypeRef?
                let status = SecItemCopyMatching(query as CFDictionary, &result)

                if status == errSecSuccess, let data = result as? Data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: KeychainError.loadFailed(status))
                }
            }
        }
    }

    /// Returns true if a key entry exists (without triggering any auth prompt).
    static func hasStoredKey() -> Bool {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecUseAuthenticationUI: kSecUseAuthenticationUIFail,
            kSecUseDataProtectionKeychain: true,
        ]
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        // errSecInteractionNotAllowed means the item exists but requires user auth.
        return status == errSecSuccess || status == errSecInteractionNotAllowed
    }

    static func delete() {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecUseDataProtectionKeychain: true,
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func isTouchIDAvailable() -> Bool {
        let ctx = LAContext()
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }
        return ctx.biometryType == .touchID
    }

    // MARK: - Errors

    enum KeychainError: LocalizedError {
        case accessControlFailed
        case saveFailed(OSStatus)
        case loadFailed(OSStatus)

        var errorDescription: String? {
            switch self {
            case .accessControlFailed: "Failed to create Keychain access control policy."
            case .saveFailed(let s): "Failed to save key to Keychain (status \(s))."
            case .loadFailed(let s): "Failed to load key from Keychain (status \(s))."
            }
        }
    }
}
