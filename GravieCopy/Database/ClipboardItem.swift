import Foundation
import GRDB

struct ClipboardItem {
    var id: Int64?
    var contentType: ContentType
    var rawData: Data
    var createdAt: Date
    var isPinned: Bool
    var sourceApp: String?
    var contentHash: String

    enum ContentType: String, Codable {
        case plainText
        case rtf
        case image
    }
}

// MARK: - GRDB conformances
//
// Implemented manually with `nonisolated` so GRDB can call these from its
// internal serial queue without crossing the implicit @MainActor boundary that
// SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor adds to every type in this module.

extension ClipboardItem: TableRecord {
    nonisolated static let databaseTableName = "clipboard_items"
}

extension ClipboardItem: FetchableRecord {
    nonisolated init(row: Row) {
        id = row["id"]
        let raw: String = row["contentType"]
        contentType = ContentType(rawValue: raw) ?? .plainText
        rawData = row["rawData"]
        createdAt = row["createdAt"]
        isPinned = row["isPinned"]
        sourceApp = row["sourceApp"]
        contentHash = row["contentHash"]
    }
}

extension ClipboardItem: MutablePersistableRecord {
    nonisolated func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["contentType"] = contentType.rawValue
        container["rawData"] = rawData
        container["createdAt"] = createdAt
        container["isPinned"] = isPinned
        container["sourceApp"] = sourceApp
        container["contentHash"] = contentHash
    }

    nonisolated mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
