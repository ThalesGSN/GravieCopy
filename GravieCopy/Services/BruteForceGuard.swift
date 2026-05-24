import Foundation

/// Tracks consecutive failed password attempts and enforces progressive lockouts.
/// State is persisted in UserDefaults so a force-quit cannot reset the counter.
///
/// Lockout schedule:
///   Fail 1 → 2-minute cooldown
///   Fail 2 → 5-minute cooldown
///   Fail 3 → vault wiped
@Observable
@MainActor
final class BruteForceGuard {
    static let shared = BruteForceGuard()

    private static let maxFails = 3
    private static let lockoutDurations: [TimeInterval] = [2 * 60, 5 * 60]

    private(set) var failedAttempts: Int
    private(set) var lockedUntil: Date?

    var isLocked: Bool {
        guard let until = lockedUntil else { return false }
        return Date() < until
    }

    var remainingSeconds: Int {
        guard let until = lockedUntil else { return 0 }
        return max(0, Int(ceil(until.timeIntervalSinceNow)))
    }

    /// How many password attempts the user has left before the vault is wiped.
    var attemptsRemaining: Int { max(0, Self.maxFails - failedAttempts) }

    private init() {
        failedAttempts = UserDefaults.standard.integer(forKey: "bfFailedAttempts")
        lockedUntil    = UserDefaults.standard.object(forKey: "bfLockedUntil") as? Date
    }

    // MARK: - Events

    enum FailureOutcome {
        case lockedOut(seconds: Int)
        case vaultWiped
    }

    /// Call after each wrong password. Returns what the UI should do next.
    func recordFailure() -> FailureOutcome {
        failedAttempts += 1
        UserDefaults.standard.set(failedAttempts, forKey: "bfFailedAttempts")

        guard failedAttempts < Self.maxFails else {
            reset()
            return .vaultWiped
        }

        let idx = failedAttempts - 1
        let duration = Self.lockoutDurations[min(idx, Self.lockoutDurations.count - 1)]
        let until = Date().addingTimeInterval(duration)
        lockedUntil = until
        UserDefaults.standard.set(until, forKey: "bfLockedUntil")

        return .lockedOut(seconds: Int(duration))
    }

    /// Call after a successful unlock to clear the counter.
    func recordSuccess() { reset() }

    // MARK: - Private

    private func reset() {
        failedAttempts = 0
        lockedUntil    = nil
        UserDefaults.standard.removeObject(forKey: "bfFailedAttempts")
        UserDefaults.standard.removeObject(forKey: "bfLockedUntil")
    }
}
