import AppKit

extension Notification.Name {
    static let clipboardItemAdded = Notification.Name("us.gravie.clipboardItemAdded")
}

@Observable
final class ClipboardMonitor {
    static let shared = ClipboardMonitor()

    private(set) var isRunning = false

    private var timer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount
    private var paused = false

    private init() {}

    // MARK: - Lifecycle

    func start() {
        guard !isRunning else { return }
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    /// Temporarily ignore pasteboard changes (use during auto-paste to avoid re-capturing the injected item).
    func pause() { paused = true }
    func resume() { paused = false }

    // MARK: - Polling

    private func poll() {
        guard !paused else { return }

        let currentCount = NSPasteboard.general.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        guard let repository = DatabaseManager.shared.repository else { return }

        let frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
        guard !AppBlacklist.contains(frontmostBundleID) else { return }

        guard let item = extract(from: .general, sourceApp: frontmostBundleID) else { return }

        Task {
            try? repository.insert(item)
            NotificationCenter.default.post(name: .clipboardItemAdded, object: nil)
        }
    }

    // MARK: - Content extraction

    private func extract(from pasteboard: NSPasteboard, sourceApp: String) -> ClipboardItem? {
        let source = sourceApp.isEmpty ? nil : sourceApp

        // Prefer richest format: image → RTF → plain text.
        if let data = pasteboard.data(forType: .tiff) ?? pasteboard.data(forType: .png) {
            return makeItem(.image, data: data, source: source)
        }

        if let data = pasteboard.data(forType: .rtf) {
            return makeItem(.rtf, data: data, source: source)
        }

        if let text = pasteboard.string(forType: .string),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let data = Data(text.utf8)
            return makeItem(.plainText, data: data, source: source)
        }

        return nil
    }

    private func makeItem(_ type: ClipboardItem.ContentType, data: Data, source: String?) -> ClipboardItem {
        ClipboardItem(
            contentType: type,
            rawData: data,
            createdAt: Date(),
            isPinned: false,
            sourceApp: source,
            contentHash: ClipboardRepository.sha256Hash(of: data)
        )
    }
}
