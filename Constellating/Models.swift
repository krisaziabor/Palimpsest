import Foundation

public struct ArenaBlock: Codable, Hashable {
    public let id: Int
    public let title: String?
    public let source: BlockSource?
    public let blockClass: String?

    public struct BlockSource: Codable, Hashable {
        public let url: String?
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case source
        case blockClass = "class"
    }

    // Implement Hashable to support Set operations for deduplication
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: ArenaBlock, rhs: ArenaBlock) -> Bool {
        lhs.id == rhs.id
    }
}

public struct ArenaChannel: Codable {
    public let id: Int
    public let slug: String
    public let ownerSlug: String?
    public let title: String?
    public let username: String?
    public let blockCount: Int?
    public let connectionCount: Int?
    public let thumbnailURLs: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case slug
        case ownerSlug = "owner_slug"
        case title
        case username = "user_slug"
        case blockCount = "length"
        case connectionCount = "connection_count"
        case thumbnailURLs = "thumbnail_urls"
    }
}
