import SwiftUI

struct MenuBarContentView: View {
    @Environment(DatabaseManager.self) private var vault

    var body: some View {
        VStack(spacing: 0) {
            if vault.isLocked {
                UnlockView()
                    .environment(vault)
            } else {
                ClipboardListView()
                    .environment(vault)
            }
        }
        .frame(width: 380)
    }
}
