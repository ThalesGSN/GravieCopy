import SwiftUI
import AppKit

struct SettingsView: View {
    @Bindable private var store = SettingsStore.shared
    @State private var isAddingApp = false
    @State private var newBundleID = ""

    var body: some View {
        Form {
            generalSection
            blockedAppsSection
        }
        .formStyle(.grouped)
        .frame(minWidth: 460, minHeight: 380)
    }

    // MARK: - General

    private var generalSection: some View {
        Section("General") {
            Picker("Auto-lock after", selection: $store.autoLockInterval) {
                ForEach(SettingsStore.autoLockOptions, id: \.value) { opt in
                    Text(opt.label).tag(opt.value)
                }
            }
            Picker("Retain history for", selection: $store.retentionPeriod) {
                ForEach(SettingsStore.retentionOptions, id: \.value) { opt in
                    Text(opt.label).tag(opt.value)
                }
            }
        }
    }

    // MARK: - Blocked Apps

    private var blockedAppsSection: some View {
        Section {
            // Built-in entries — display-only
            ForEach(AppBlacklist.defaults.sorted(), id: \.self) { id in
                HStack {
                    Text(id)
                    Spacer()
                    Text("Built-in")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            // Custom entries — removable
            ForEach(store.customBlacklist.sorted(), id: \.self) { id in
                HStack {
                    Text(id)
                    Spacer()
                    Button(role: .destructive) {
                        store.customBlacklist.remove(id)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Inline add row
            if isAddingApp {
                HStack(spacing: 8) {
                    TextField("com.example.app", text: $newBundleID)
                        .onSubmit { commitNewApp() }
                    Button("Add") { commitNewApp() }
                        .disabled(newBundleID.trimmingCharacters(in: .whitespaces).isEmpty)
                    Button("Cancel") { cancelAdd() }
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 16) {
                    Button {
                        isAddingApp = true
                    } label: {
                        Label("Add bundle ID…", systemImage: "plus")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)

                    // Pick from currently running apps that aren't already blocked.
                    Menu {
                        ForEach(pickableRunningApps, id: \.bundleIdentifier) { app in
                            Button(app.localizedName ?? (app.bundleIdentifier ?? "Unknown")) {
                                if let id = app.bundleIdentifier {
                                    store.customBlacklist.insert(id)
                                }
                            }
                        }
                        if pickableRunningApps.isEmpty {
                            Text("No unblocked apps running")
                        }
                    } label: {
                        Label("Pick running app…", systemImage: "chevron.down")
                            .foregroundStyle(Color.accentColor)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("Blocked Apps")
        } footer: {
            Text("Clipboard changes are not recorded when these apps are in focus.")
        }
    }

    // MARK: - Helpers

    private var pickableRunningApps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { app in
                guard let id = app.bundleIdentifier, !id.isEmpty else { return false }
                guard app.bundleIdentifier != Bundle.main.bundleIdentifier else { return false }
                guard !AppBlacklist.defaults.contains(id) else { return false }
                guard !store.customBlacklist.contains(id) else { return false }
                return app.localizedName != nil
            }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    private func commitNewApp() {
        let id = newBundleID.trimmingCharacters(in: .whitespaces)
        guard !id.isEmpty else { return }
        store.customBlacklist.insert(id)
        cancelAdd()
    }

    private func cancelAdd() {
        newBundleID = ""
        isAddingApp = false
    }
}
