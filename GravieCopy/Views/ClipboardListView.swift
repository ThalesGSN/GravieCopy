import SwiftUI
import AppKit

struct ClipboardListView: View {
    @Environment(DatabaseManager.self) private var vault

    @State private var allItems: [ClipboardItem] = []
    @State private var searchText = ""
    @State private var selectedID: Int64?
    @State private var pastePlainText = false
    @FocusState private var searchFocused: Bool

    private var filteredItems: [ClipboardItem] {
        guard !searchText.isEmpty else { return allItems }
        let q = searchText.lowercased()
        return allItems.filter { item in
            switch item.contentType {
            case .image: return false
            case .plainText:
                return (String(data: item.rawData, encoding: .utf8) ?? "").lowercased().contains(q)
            case .rtf:
                let plain = (try? NSAttributedString(
                    data: item.rawData,
                    options: [.documentType: NSAttributedString.DocumentType.rtf],
                    documentAttributes: nil
                ).string) ?? ""
                return plain.lowercased().contains(q)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            listArea
            Divider()
            footer
            // Hidden button captures Cmd+Ctrl+Shift+V at window level.
            Button("", action: pasteSelectedPlainText)
                .keyboardShortcut("v", modifiers: [.command, .control, .shift])
                .frame(width: 0, height: 0)
                .hidden()
        }
        .onAppear {
            loadItems()
            searchFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .clipboardItemAdded)) { _ in
            loadItems()
        }
        .onChange(of: searchText) {
            selectedID = filteredItems.first?.id
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search clipboard…", text: $searchText)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .onKeyPress(.upArrow)   { moveSelection(-1);         return .handled }
                .onKeyPress(.downArrow) { moveSelection(1);           return .handled }
                .onKeyPress(.return)    { pasteSelected();             return .handled }
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - List

    @ViewBuilder
    private var listArea: some View {
        if filteredItems.isEmpty {
            emptyState
        } else {
            ScrollViewReader { proxy in
                List(filteredItems, id: \.id) { item in
                    ClipboardItemRow(
                        item: item,
                        isSelected: item.id == selectedID,
                        onSelect: { selectedID = item.id },
                        onPin:    { togglePin(item) },
                        onDelete: { deleteItem(item) }
                    )
                    .id(item.id)
                    .listRowInsets(EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .frame(height: 340)
                .onChange(of: selectedID) {
                    if let id = selectedID { proxy.scrollTo(id) }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: searchText.isEmpty ? "clock.arrow.circlepath" : "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text(searchText.isEmpty ? "No clipboard history yet" : "No results for \"\(searchText)\"")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 340)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 0) {
            if !AutoPasteService.shared.hasAccessibilityPermission {
                Divider()
                Button {
                    AutoPasteService.shared.requestPermissionIfNeeded()
                } label: {
                    Label("Grant Accessibility access for auto-paste", systemImage: "hand.raised")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            HStack(spacing: 12) {
            Text("\(allItems.count) item\(allItems.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()

            Toggle("Plain text", isOn: $pastePlainText)
                .toggleStyle(.checkbox)
                .font(.caption)
                .help("Strip formatting when pasting")

            Button { vault.lock() } label: {
                Image(systemName: "lock")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Lock vault")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Data

    private func loadItems() {
        guard let repo = vault.repository else { return }
        allItems = (try? repo.fetchAll()) ?? []
        if selectedID == nil || !allItems.contains(where: { $0.id == selectedID }) {
            selectedID = allItems.first?.id
        }
    }

    // MARK: - Actions

    private func moveSelection(_ delta: Int) {
        let items = filteredItems
        guard !items.isEmpty else { return }
        if let currentID = selectedID,
           let idx = items.firstIndex(where: { $0.id == currentID }) {
            let newIdx = max(0, min(items.count - 1, idx + delta))
            selectedID = items[newIdx].id
        } else {
            selectedID = delta >= 0 ? items.first?.id : items.last?.id
        }
    }

    private func pasteSelected() {
        guard let id = selectedID,
              let item = filteredItems.first(where: { $0.id == id }) else { return }
        paste(item)
    }

    private func pasteSelectedPlainText() {
        guard let id = selectedID,
              let item = filteredItems.first(where: { $0.id == id }) else { return }
        paste(item, forcePlainText: true)
    }

    private func paste(_ item: ClipboardItem, forcePlainText: Bool = false) {
        ClipboardMonitor.shared.pause()

        let pb = NSPasteboard.general
        pb.clearContents()

        if pastePlainText || forcePlainText {
            let text: String
            switch item.contentType {
            case .plainText: text = String(data: item.rawData, encoding: .utf8) ?? ""
            case .rtf:       text = (try? NSAttributedString(data: item.rawData, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil).string) ?? ""
            case .image:     text = ""
            }
            if !text.isEmpty { pb.setString(text, forType: .string) }
        } else {
            switch item.contentType {
            case .plainText:
                if let text = String(data: item.rawData, encoding: .utf8) {
                    pb.setString(text, forType: .string)
                }
            case .rtf:
                pb.setData(item.rawData, forType: .rtf)
            case .image:
                pb.setData(item.rawData, forType: .tiff)
            }
        }

        // Close popover → restore focus → inject Cmd+V.
        AutoPasteService.shared.performPaste()

        // Keep monitor paused long enough for the Cmd+V injection to complete
        // before we start watching for clipboard changes again.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            ClipboardMonitor.shared.resume()
        }
    }

    private func togglePin(_ item: ClipboardItem) {
        guard let repo = vault.repository else { return }
        try? repo.togglePin(item)
        loadItems()
    }

    private func deleteItem(_ item: ClipboardItem) {
        guard let repo = vault.repository else { return }
        try? repo.delete(item)
        if selectedID == item.id { selectedID = allItems.first(where: { $0.id != item.id })?.id }
        loadItems()
    }
}
