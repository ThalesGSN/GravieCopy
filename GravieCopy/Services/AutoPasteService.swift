import AppKit
import ApplicationServices

@Observable
@MainActor
final class AutoPasteService {
    static let shared = AutoPasteService()

    // Captured before we show our popover so we know where to paste back.
    private(set) var previousApp: NSRunningApplication?

    var hasAccessibilityPermission: Bool { AXIsProcessTrusted() }

    private init() {}

    // Call this right before showing the popover so the frontmost app is
    // still the user's target application (not ours).
    func captureTargetApp() {
        let front = NSWorkspace.shared.frontmostApplication
        if front?.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp = front
        }
    }

    // Show the system prompt if Accessibility access hasn't been granted yet.
    func requestPermissionIfNeeded() {
        guard !hasAccessibilityPermission else { return }
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    // Close our popover, restore focus to the target app, then inject Cmd+V.
    func performPaste() {
        (NSApp.delegate as? AppDelegate)?.closePopover()

        guard let app = previousApp else { return }

        // Restore focus to the app the user was working in.
        app.activate(options: .activateIgnoringOtherApps)

        guard hasAccessibilityPermission else { return }

        // Brief delay lets the window manager complete the focus handoff
        // before we inject the keystroke.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.sendCmdV()
        }
    }

    private func sendCmdV() {
        let src = CGEventSource(stateID: .hidSystemState)
        let kV: CGKeyCode = 9
        let down = CGEvent(keyboardEventSource: src, virtualKey: kV, keyDown: true)
        let up   = CGEvent(keyboardEventSource: src, virtualKey: kV, keyDown: false)
        down?.flags = .maskCommand
        up?.flags   = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
