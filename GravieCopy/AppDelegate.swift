import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        setupPopover()
        setupHotkey()
        ClipboardMonitor.shared.start()
        AutoPasteService.shared.requestPermissionIfNeeded()
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "doc.on.clipboard",
            accessibilityDescription: "GravieCopy"
        )
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.target = self
    }

    private func setupPopover() {
        let content = MenuBarContentView()
            .environment(DatabaseManager.shared)
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: content)
    }

    private func setupHotkey() {
        HotkeyManager.shared.onActivate = { [weak self] in
            DispatchQueue.main.async { self?.togglePopover() }
        }
        HotkeyManager.shared.register()
    }

    // MARK: - Popover control

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            closePopover()
        } else {
            // Capture the user's active app before we steal focus.
            AutoPasteService.shared.captureTargetApp()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func closePopover() {
        popover.performClose(nil)
    }
}
