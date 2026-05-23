import Foundation
import CryptoKit
import GRDB

struct ClipboardRepository {
    let db: any DatabaseWriter

    // MARK: - Write

    /// Inserts an item, ignoring duplicates based on content hash.
    func insert(_ item: ClipboardItem) throws {
        var mutable = item
        try db.write { database in
            let exists = try ClipboardItem
                .filter(Column("contentHash") == item.contentHash)
                .fetchOne(database) != nil
            guard !exists else { return }
            try mutable.insert(database)
        }
    }

    func delete(_ item: ClipboardItem) throws {
        try db.write { database in
            try ClipboardItem
                .filter(Column("id") == item.id)
                .deleteAll(database)
        }
    }

    func togglePin(_ item: ClipboardItem) throws {
        try db.write { database in
            try database.execute(
                sql: "UPDATE clipboard_items SET isPinned = ? WHERE id = ?",
                arguments: [!item.isPinned, item.id]
            )
        }
    }

    /// Deletes all unpinned items older than the given date.
    func deleteExpired(before cutoff: Date) throws {
        try db.write { database in
            try database.execute(
                sql: "DELETE FROM clipboard_items WHERE isPinned = 0 AND createdAt < ?",
                arguments: [cutoff]
            )
        }
    }

    func deleteAll() throws {
        try db.write { database in
            try ClipboardItem.deleteAll(database)
        }
    }

    // MARK: - Read

    func fetchAll() throws -> [ClipboardItem] {
        try db.read { database in
            try ClipboardItem
                .order(Column("isPinned").desc, Column("createdAt").desc)
                .fetchAll(database)
        }
    }

    /// Full-text search performed entirely in memory once items are decrypted.
    func search(query: String) throws -> [ClipboardItem] {
        let all = try fetchAll()
        guard !query.isEmpty else { return all }

        let lowercased = query.lowercased()
        return all.filter { item in
            guard item.contentType == .plainText || item.contentType == .rtf,
                  let text = String(data: item.rawData, encoding: .utf8) else { return false }
            return text.lowercased().contains(lowercased)
        }
    }
}

// MARK: - Hashing helper

extension ClipboardRepository {
    static func sha256Hash(of data: Data) -> String {
        SHA256.hash(data: data)
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }
}
