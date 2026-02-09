import Foundation

struct DiscoveredURL: Identifiable {
    let url: String
    let count: Int
    let isTopResult: Bool
    var id: String { url }
}

struct ClassifiedBlock: Identifiable {
    let block: ArenaBlock
    let isExact: Bool
    var id: Int { block.id }
}

struct MatchResult {
    let exact: Int
    let inexact: Int
    let classifiedBlocks: [ClassifiedBlock]
}

struct SearchResults {
    let exactCount: Int
    let inexactCount: Int
    let channels: [ArenaChannel]
    let discoveredURLs: [DiscoveredURL]
    let classifiedBlocks: [ClassifiedBlock]
}

enum SearchOutcome {
    case complete(SearchResults)
    case rateLimited(partial: SearchResults, resumeState: SearchResumeState)
}

struct SearchResumeState {
    let originalURL: String
    let blocks: [ArenaBlock]
    let channels: [ArenaChannel]
    let urlFrequency: [String: Int]
    let lastProcessedBlockIndex: Int
    let lastProcessedChannelIndex: Int
    /// When set, more block pages remain to fetch. Used for interleaved search.
    let blockSearchQuery: String?
    let nextBlockPageToFetch: Int
    let totalBlockPages: Int

    init(
        originalURL: String,
        blocks: [ArenaBlock],
        channels: [ArenaChannel],
        urlFrequency: [String: Int],
        lastProcessedBlockIndex: Int,
        lastProcessedChannelIndex: Int,
        blockSearchQuery: String? = nil,
        nextBlockPageToFetch: Int = 1,
        totalBlockPages: Int = 1
    ) {
        self.originalURL = originalURL
        self.blocks = blocks
        self.channels = channels
        self.urlFrequency = urlFrequency
        self.lastProcessedBlockIndex = lastProcessedBlockIndex
        self.lastProcessedChannelIndex = lastProcessedChannelIndex
        self.blockSearchQuery = blockSearchQuery
        self.nextBlockPageToFetch = nextBlockPageToFetch
        self.totalBlockPages = totalBlockPages
    }
}

struct DualSearchQuery {
    let domainQuery: String
    let htmlTitleQuery: String?
    let originalURL: String
}
