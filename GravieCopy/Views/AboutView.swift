import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 0) {
            // Icon + name block
            VStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 96, height: 96)
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)

                Text("GravieCopy")
                    .font(.title)
                    .fontWeight(.semibold)

                Text("Version \(version)  (\(build))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 32)
            .padding(.bottom, 24)

            Divider()

            // Feature highlights
            VStack(alignment: .leading, spacing: 10) {
                featureRow("lock.shield.fill",      "AES-256 encrypted vault",           .blue)
                featureRow("touchid",               "Touch ID + Keychain unlock",         .blue)
                featureRow("key.fill",              "PBKDF2-SHA256 key derivation",       .indigo)
                featureRow("antenna.radiowaves.left.and.right.slash",
                                                    "Zero telemetry — no network access", .green)
                featureRow("internaldrive.fill",    "100 % local storage",               .green)
                featureRow("hand.raised.fill",      "LGPD / HIPAA-conscious design",      .orange)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)

            Divider()

            // Copyright
            Text("© 2026 Gravie · MIT License")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.vertical, 14)
        }
        .frame(width: 320)
    }

    // MARK: - Helpers

    private func featureRow(_ icon: String, _ label: String, _ color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
