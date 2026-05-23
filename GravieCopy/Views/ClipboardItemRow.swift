import SwiftUI
import AppKit

extension ClipboardItem.ContentType {
    var systemImage: String {
        switch self {
        case .plainText: "doc.text"
        case .rtf:       "doc.richtext"
        case .image:     "photo"
        }
    }
}

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onPin: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: item.contentType.systemImage)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 18)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                preview
                metaLine
            }

            Spacer(minLength: 0)

            if isHovered || isSelected {
                actionButtons
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(rowBackground)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { isHovered = $0 }
    }

    // MARK: - Content

    @ViewBuilder
    private var preview: some View {
        switch item.contentType {
        case .plainText:
            Text(String(data: item.rawData, encoding: .utf8) ?? "")
                .lineLimit(2)
                .font(.system(size: 12))

        case .rtf:
            Text(plainTextFromRTF ?? "Rich text")
                .lineLimit(2)
                .font(.system(size: 12))

        case .image:
            if let img = NSImage(data: item.rawData) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 44)
                    .clipped()
                    .cornerRadius(4)
            }
        }
    }

    private var metaLine: some View {
        HStack(spacing: 6) {
            if let sourceApp = item.sourceApp {
                Text(shortAppName(sourceApp))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            Text(RelativeDateTimeFormatter().localizedString(for: item.createdAt, relativeTo: Date()))
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Actions

    private var actionButtons: some View {
        HStack(spacing: 6) {
            Button(action: onPin) {
                Image(systemName: item.isPinned ? "pin.slash" : "pin")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(item.isPinned ? .orange : .secondary)
            .help(item.isPinned ? "Unpin" : "Pin")

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
            .help("Delete")
        }
    }

    // MARK: - Helpers

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
    }

    private var plainTextFromRTF: String? {
        try? NSAttributedString(
            data: item.rawData,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        ).string
    }

    private func shortAppName(_ bundleID: String) -> String {
        bundleID.split(separator: ".").last.map(String.init) ?? bundleID
    }
}
