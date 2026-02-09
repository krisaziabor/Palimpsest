import Foundation

private struct ChannelsFetchResult {
    let channels: [ArenaChannel]
    let lastProcessedIndex: Int
    let hitRateLimit: Bool
}

private struct URLFrequencyFetchResult {
    let frequency: [String: Int]
    let lastProcessedIndex: Int
    let hitRateLimit: Bool
}

// swiftlint:disable type_body_length function_body_length file_length
// Interleaves block fetching with channel/URL extraction so channels and websites
// appear early, even when rate limit is hit. Blocks are low-value; channels and URLs are high-value.
class SearchService {
    private let arenaAPIService: ArenaAPIService
    private let htmlTitleExtractor: HTMLTitleExtractor

    init(
        arenaAPIService: ArenaAPIService,
        htmlTitleExtractor: HTMLTitleExtractor = HTMLTitleExtractor()
    ) {
        self.arenaAPIService = arenaAPIService
        self.htmlTitleExtractor = htmlTitleExtractor
    }

    func performDualSearch(
        originalURL: String,
        resumeState: SearchResumeState? = nil,
        onProgress: (@Sendable (SearchResults) -> Void)? = nil
    ) async throws -> SearchOutcome {
        do {
            guard URL(string: originalURL) != nil else {
                throw URLError(.badURL)
            }

            if let resume = resumeState {
                return try await resumeAndContinue(
                    resume: resume,
                    originalURL: originalURL,
                    onProgress: onProgress
                )
            }

            return try await runInterleavedSearch(
                originalURL: originalURL,
                onProgress: onProgress
            )
        } catch {
            print("❌ SearchService error: \(error)")
            throw error
        }
    }

    /// Resume from a rate-limited partial. Processes remaining channels/URLs from existing blocks.
    private func resumeAndContinue(
        resume: SearchResumeState,
        originalURL: String,
        onProgress: (@Sendable (SearchResults) -> Void)?
    ) async throws -> SearchOutcome {
        var blocks = resume.blocks
        var blockSearchQuery = resume.blockSearchQuery
        var nextBlockPage = resume.nextBlockPageToFetch
        var totalBlockPages = resume.totalBlockPages

        if let query = blockSearchQuery, nextBlockPage <= totalBlockPages, nextBlockPage <= 40 {
            do {
                let pageResult = try await arenaAPIService.fetchBlocksPage(query: query, page: nextBlockPage)
                blocks.append(contentsOf: pageResult.blocks)
                totalBlockPages = pageResult.totalPages
                nextBlockPage += 1
                if nextBlockPage > totalBlockPages {
                    blockSearchQuery = nil
                }
            } catch APIError.rateLimitExceeded {
                return makeRateLimitedResult(
                    originalURL: originalURL,
                    blocks: blocks,
                    channels: resume.channels,
                    urlFrequency: resume.urlFrequency,
                    lastBlockIndex: resume.lastProcessedBlockIndex,
                    lastChannelIndex: resume.lastProcessedChannelIndex,
                    blockSearchQuery: blockSearchQuery,
                    nextBlockPageToFetch: nextBlockPage,
                    totalBlockPages: totalBlockPages
                )
            } catch APIError.httpError(400, _) {
                blockSearchQuery = nil
            }
        }

        let uniqueBlocks = Array(Set(blocks))
        var channels = resume.channels
        var urlFrequency = resume.urlFrequency
        var lastBlockIndex = resume.lastProcessedBlockIndex
        var lastChannelIndex = resume.lastProcessedChannelIndex

        let channelsResult = try await fetchChannelsIncremental(
            from: uniqueBlocks,
            startIndex: lastBlockIndex,
            existingChannels: channels
        )
        channels = channelsResult.channels
        lastBlockIndex = channelsResult.lastProcessedIndex

        reportProgress(
            blocks: uniqueBlocks,
            channels: channels,
            urlFrequency: urlFrequency,
            originalURL: originalURL,
            onProgress: onProgress
        )

        if channelsResult.hitRateLimit {
            return makeRateLimitedResult(
                originalURL: originalURL,
                blocks: uniqueBlocks,
                channels: channels,
                urlFrequency: urlFrequency,
                lastBlockIndex: lastBlockIndex,
                lastChannelIndex: lastChannelIndex,
                blockSearchQuery: blockSearchQuery,
                nextBlockPageToFetch: nextBlockPage,
                totalBlockPages: totalBlockPages
            )
        }

        let uniqueChannels = deduplicateChannels(channels)
        let urlResult = try await fetchURLFrequencyIncremental(
            from: uniqueChannels,
            startIndex: lastChannelIndex,
            existingFrequency: urlFrequency
        )
        urlFrequency = urlResult.frequency
        lastChannelIndex = urlResult.lastProcessedIndex

        reportProgress(
            blocks: uniqueBlocks,
            channels: uniqueChannels,
            urlFrequency: urlFrequency,
            originalURL: originalURL,
            onProgress: onProgress
        )

        if urlResult.hitRateLimit {
            return makeRateLimitedResult(
                originalURL: originalURL,
                blocks: uniqueBlocks,
                channels: uniqueChannels,
                urlFrequency: urlFrequency,
                lastBlockIndex: uniqueBlocks.count,
                lastChannelIndex: lastChannelIndex,
                blockSearchQuery: blockSearchQuery,
                nextBlockPageToFetch: nextBlockPage,
                totalBlockPages: totalBlockPages
            )
        }

        if blockSearchQuery != nil, nextBlockPage <= totalBlockPages, nextBlockPage <= 40 {
            return try await runInterleavedSearch(
                originalURL: originalURL,
                onProgress: onProgress,
                initialState: InterleavedState(
                    blocks: uniqueBlocks,
                    channels: uniqueChannels,
                    urlFrequency: urlFrequency,
                    lastProcessedBlockIndex: uniqueBlocks.count,
                    lastProcessedChannelIndex: uniqueChannels.count,
                    blockSearchQuery: blockSearchQuery,
                    nextBlockPageToFetch: nextBlockPage,
                    totalBlockPages: totalBlockPages
                )
            )
        }

        let results = buildSearchResults(
            blocks: uniqueBlocks,
            channels: uniqueChannels,
            urlFrequency: urlFrequency,
            originalURL: originalURL
        )
        return .complete(results)
    }

    private struct InterleavedState {
        var blocks: [ArenaBlock]
        var channels: [ArenaChannel]
        var urlFrequency: [String: Int]
        var lastProcessedBlockIndex: Int
        var lastProcessedChannelIndex: Int
        var blockSearchQuery: String?
        var nextBlockPageToFetch: Int
        var totalBlockPages: Int
    }

    /// Interleaved flow: fetch 1 page blocks → channels for those blocks → URLs (first page) for new channels → report.
    /// Ensures channels and websites appear early even when rate limit hits.
    private func runInterleavedSearch(
        originalURL: String,
        onProgress: (@Sendable (SearchResults) -> Void)?,
        initialState: InterleavedState? = nil
    ) async throws -> SearchOutcome {
        let htmlTitle = await extractHTMLTitle(from: originalURL)
        guard let query = htmlTitle, !query.isEmpty else {
            print("⚠️ HTML title extraction failed or empty, skipping title search")
            return .complete(buildSearchResults(
                blocks: [],
                channels: [],
                urlFrequency: [:],
                originalURL: originalURL
            ))
        }

        print("🔍 Searching with HTML title: '\(query)'")

        var state: InterleavedState
        if let initial = initialState {
            state = initial
        } else {
            let (pageBlocks, totalPages) = try await fetchBlocksPageOrBail(query: query, page: 1)
            state = InterleavedState(
                blocks: pageBlocks,
                channels: [],
                urlFrequency: [:],
                lastProcessedBlockIndex: 0,
                lastProcessedChannelIndex: 0,
                blockSearchQuery: query,
                nextBlockPageToFetch: 2,
                totalBlockPages: totalPages
            )
        }

        while true {
            let uniqueBlocks = Array(Set(state.blocks))

            let channelsResult = try await fetchChannelsIncremental(
                from: uniqueBlocks,
                startIndex: state.lastProcessedBlockIndex,
                existingChannels: state.channels
            )
            state.channels = channelsResult.channels
            state.lastProcessedBlockIndex = channelsResult.lastProcessedIndex

            let uniqueChannels = deduplicateChannels(state.channels)
            let urlResult = try await fetchURLFrequencyIncremental(
                from: uniqueChannels,
                startIndex: state.lastProcessedChannelIndex,
                existingFrequency: state.urlFrequency
            )
            state.urlFrequency = urlResult.frequency
            state.lastProcessedChannelIndex = urlResult.lastProcessedIndex

            reportProgress(
                blocks: uniqueBlocks,
                channels: uniqueChannels,
                urlFrequency: state.urlFrequency,
                originalURL: originalURL,
                onProgress: onProgress
            )

            if channelsResult.hitRateLimit {
                return makeRateLimitedResult(
                    originalURL: originalURL,
                    blocks: uniqueBlocks,
                    channels: state.channels,
                    urlFrequency: state.urlFrequency,
                    lastBlockIndex: state.lastProcessedBlockIndex,
                    lastChannelIndex: state.lastProcessedChannelIndex,
                    blockSearchQuery: state.blockSearchQuery,
                    nextBlockPageToFetch: state.nextBlockPageToFetch,
                    totalBlockPages: state.totalBlockPages
                )
            }
            if urlResult.hitRateLimit {
                return makeRateLimitedResult(
                    originalURL: originalURL,
                    blocks: uniqueBlocks,
                    channels: uniqueChannels,
                    urlFrequency: state.urlFrequency,
                    lastBlockIndex: uniqueBlocks.count,
                    lastChannelIndex: state.lastProcessedChannelIndex,
                    blockSearchQuery: state.blockSearchQuery,
                    nextBlockPageToFetch: state.nextBlockPageToFetch,
                    totalBlockPages: state.totalBlockPages
                )
            }

            guard let blockQuery = state.blockSearchQuery,
                  state.nextBlockPageToFetch <= state.totalBlockPages,
                  state.nextBlockPageToFetch <= 40
            else {
                let results = buildSearchResults(
                    blocks: uniqueBlocks,
                    channels: uniqueChannels,
                    urlFrequency: state.urlFrequency,
                    originalURL: originalURL
                )
                return .complete(results)
            }

            do {
                let (pageBlocks, totalPages) = try await arenaAPIService.fetchBlocksPage(
                    query: blockQuery,
                    page: state.nextBlockPageToFetch
                )
                state.blocks.append(contentsOf: pageBlocks)
                state.totalBlockPages = totalPages
                state.nextBlockPageToFetch += 1
                if state.nextBlockPageToFetch > totalPages {
                    state.blockSearchQuery = nil
                }
            } catch APIError.rateLimitExceeded {
                return makeRateLimitedResult(
                    originalURL: originalURL,
                    blocks: uniqueBlocks,
                    channels: uniqueChannels,
                    urlFrequency: state.urlFrequency,
                    lastBlockIndex: uniqueBlocks.count,
                    lastChannelIndex: uniqueChannels.count,
                    blockSearchQuery: state.blockSearchQuery,
                    nextBlockPageToFetch: state.nextBlockPageToFetch,
                    totalBlockPages: state.totalBlockPages
                )
            } catch APIError.httpError(400, _) {
                print("⚠️ API limit reached at block search page \(state.nextBlockPageToFetch)")
                state.blockSearchQuery = nil
            }
        }
    }

    private func fetchBlocksPageOrBail(query: String, page: Int) async throws -> (
        blocks: [ArenaBlock],
        totalPages: Int
    ) {
        do {
            return try await arenaAPIService.fetchBlocksPage(query: query, page: page)
        } catch APIError.httpError(400, _) {
            print("⚠️ API limit reached at block search page \(page)")
            return ([], 1)
        }
    }

    private func deduplicateChannels(_ channels: [ArenaChannel]) -> [ArenaChannel] {
        var unique: [ArenaChannel] = []
        var seen: Set<String> = []
        for channel in channels where !seen.contains(channel.slug) {
            unique.append(channel)
            seen.insert(channel.slug)
        }
        return unique
    }

    // swiftlint:disable:next function_parameter_count
    private func makeRateLimitedResult(
        originalURL: String,
        blocks: [ArenaBlock],
        channels: [ArenaChannel],
        urlFrequency: [String: Int],
        lastBlockIndex: Int,
        lastChannelIndex: Int,
        blockSearchQuery: String? = nil,
        nextBlockPageToFetch: Int = 1,
        totalBlockPages: Int = 1
    ) -> SearchOutcome {
        let state = SearchResumeState(
            originalURL: originalURL,
            blocks: blocks,
            channels: channels,
            urlFrequency: urlFrequency,
            lastProcessedBlockIndex: lastBlockIndex,
            lastProcessedChannelIndex: lastChannelIndex,
            blockSearchQuery: blockSearchQuery,
            nextBlockPageToFetch: nextBlockPageToFetch,
            totalBlockPages: totalBlockPages
        )
        let partial = buildSearchResults(
            blocks: blocks,
            channels: channels,
            urlFrequency: urlFrequency,
            originalURL: originalURL
        )
        return .rateLimited(partial: partial, resumeState: state)
    }

    private func fetchChannelsIncremental(
        from blocks: [ArenaBlock],
        startIndex: Int,
        existingChannels: [ArenaChannel]
    ) async throws -> ChannelsFetchResult {
        var allChannels = existingChannels

        for index in startIndex ..< blocks.count {
            do {
                let blockChannels = try await arenaAPIService.fetchChannels(for: blocks[index].id)
                allChannels.append(contentsOf: blockChannels)
            } catch APIError.rateLimitExceeded {
                print("⚠️ Rate limit in fetchChannels at block index \(index)")
                return ChannelsFetchResult(channels: allChannels, lastProcessedIndex: index, hitRateLimit: true)
            }
        }

        return ChannelsFetchResult(channels: allChannels, lastProcessedIndex: blocks.count, hitRateLimit: false)
    }

    private func fetchURLFrequencyIncremental(
        from channels: [ArenaChannel],
        startIndex: Int,
        existingFrequency: [String: Int]
    ) async throws -> URLFrequencyFetchResult {
        var urlFrequency = existingFrequency

        for index in startIndex ..< channels.count {
            do {
                let contents = try await arenaAPIService.fetchChannelContentsFirstPage(slug: channels[index].slug)
                for block in contents {
                    if let sourceURL = block.source?.url {
                        urlFrequency[sourceURL, default: 0] += 1
                    }
                }
            } catch APIError.rateLimitExceeded {
                print("⚠️ Rate limit in fetchURLFrequency at channel index \(index)")
                return URLFrequencyFetchResult(frequency: urlFrequency, lastProcessedIndex: index, hitRateLimit: true)
            }
        }

        return URLFrequencyFetchResult(frequency: urlFrequency, lastProcessedIndex: channels.count, hitRateLimit: false)
    }

    private func reportProgress(
        blocks: [ArenaBlock],
        channels: [ArenaChannel],
        urlFrequency: [String: Int],
        originalURL: String,
        onProgress: (@Sendable (SearchResults) -> Void)?
    ) {
        let results = buildSearchResults(
            blocks: blocks,
            channels: channels,
            urlFrequency: urlFrequency,
            originalURL: originalURL
        )
        onProgress?(results)
    }

    private func buildSearchResults(
        blocks: [ArenaBlock],
        channels: [ArenaChannel],
        urlFrequency: [String: Int],
        originalURL: String
    ) -> SearchResults {
        let matchCounts = countMatches(in: blocks, against: originalURL)
        let discoveredURLs = createDiscoveredURLs(from: urlFrequency)
        return SearchResults(
            exactCount: matchCounts.exact,
            inexactCount: matchCounts.inexact,
            channels: channels,
            discoveredURLs: discoveredURLs,
            classifiedBlocks: matchCounts.classifiedBlocks
        )
    }

    private func extractHTMLTitle(from urlString: String) async -> String? {
        do {
            let title = try await htmlTitleExtractor.extractTitle(from: urlString)
            print("📄 Extracted HTML title: '\(title)'")
            return title
        } catch {
            print("❌ Failed to extract HTML title: \(error.localizedDescription)")
            return nil
        }
    }

    private func countMatches(in blocks: [ArenaBlock], against originalURL: String) -> MatchResult {
        var exact = 0
        var inexact = 0
        var classifiedBlocks: [ClassifiedBlock] = []

        for block in blocks {
            if let sourceURL = block.source?.url {
                let (matches, isExact) = urlsMatch(originalURL, sourceURL)
                if matches {
                    classifiedBlocks.append(ClassifiedBlock(block: block, isExact: isExact))
                    if isExact { exact += 1 } else { inexact += 1 }
                }
            }
        }

        return MatchResult(exact: exact, inexact: inexact, classifiedBlocks: classifiedBlocks)
    }

    private func createDiscoveredURLs(from urlFrequency: [String: Int]) -> [DiscoveredURL] {
        let sortedURLs = urlFrequency.sorted { $0.value > $1.value }
        let maxCount = sortedURLs.first?.value ?? 0

        return sortedURLs.map { url, count in
            DiscoveredURL(url: url, count: count, isTopResult: count == maxCount && maxCount > 1)
        }
    }
}

// swiftlint:enable type_body_length function_body_length

// MARK: - URL Utilities

func stripToDomain(from url: URL) -> String {
    let host = url.host?.replacingOccurrences(of: "www.", with: "") ?? url.absoluteString
    let comps = host.components(separatedBy: ".")
    return comps.first ?? host
}

func urlsMatch(_ url1: String, _ url2: String) -> (matches: Bool, isExact: Bool) {
    let clean1 = url1.lowercased()
        .replacingOccurrences(of: "https://", with: "")
        .replacingOccurrences(of: "http://", with: "")
        .replacingOccurrences(of: "www.", with: "")

    let clean2 = url2.lowercased()
        .replacingOccurrences(of: "https://", with: "")
        .replacingOccurrences(of: "http://", with: "")
        .replacingOccurrences(of: "www.", with: "")

    if clean1 == clean2 {
        return (true, true)
    }

    let domain1 = clean1.components(separatedBy: "/").first ?? clean1
    let domain2 = clean2.components(separatedBy: "/").first ?? clean2

    if domain1 == domain2 {
        return (true, false)
    }

    return (false, false)
}
