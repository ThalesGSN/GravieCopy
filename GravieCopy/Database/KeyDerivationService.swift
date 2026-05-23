import Foundation
import CommonCrypto

enum KeyDerivationService {
    nonisolated(unsafe) static let derivedKeyLength = 32
    nonisolated(unsafe) static let pbkdf2Iterations: UInt32 = 100_000
    nonisolated(unsafe) static let saltLength = 32

    nonisolated static func deriveKey(from password: String, salt: Data) throws -> Data {
        guard let passwordData = password.data(using: .utf8) else {
            throw KeyDerivationError.invalidPassword
        }

        var derivedKey = Data(count: derivedKeyLength)

        let status: Int32 = derivedKey.withUnsafeMutableBytes { derivedBytes in
            passwordData.withUnsafeBytes { passwordBytes in
                salt.withUnsafeBytes { saltBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        passwordData.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        pbkdf2Iterations,
                        derivedBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        derivedKeyLength
                    )
                }
            }
        }

        guard status == kCCSuccess else {
            throw KeyDerivationError.derivationFailed(Int(status))
        }

        return derivedKey
    }

    static func generateSalt() -> Data {
        var bytes = [UInt8](repeating: 0, count: saltLength)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
    }

    enum KeyDerivationError: LocalizedError {
        case invalidPassword
        case derivationFailed(Int)

        var errorDescription: String? {
            switch self {
            case .invalidPassword: "The password could not be encoded."
            case .derivationFailed(let code): "Key derivation failed with status \(code)."
            }
        }
    }
}
