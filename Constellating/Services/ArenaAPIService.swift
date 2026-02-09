import Foundation

enum APIError: Error {
    case httpError(Int, String)
    case invalidResponse
    case decodingError(Error)
    case rateLimitExceeded

    var localizedDescription: String {
        switch self {
        case let .httpError(code, message):
            "HTTP Error \(code): \(message)"
        case .invalidResponse:
            "Invalid API response"
        case let .decodingError(error):
            "Decoding error: \(error.localizedDescription)"
        case .rateLimitExceeded:
            "Rate limit exceeded. Tap Continue Search to resume when the limit resets."
        }
    }
}

struct ArenaBlockSearchResponse: Decodable {
    let blocks: [ArenaBlock]
    let totalPages: Int?

    enum CodingKeys: String, CodingKey {
        case blocks
        case totalPages = "total_pages"
    }
}

struct ArenaChannelResponse: Decodable {
    let channels: [ArenaChannel]
    let totalPages: Int?

    enum CodingKeys: String, CodingKey {
        case channels
        case totalPages = "total_pages"
    }
}

struct ArenaChannelContentsResponse: Decodable {
    let contents: [ArenaBlock]
    let totalPages: Int?

    enum CodingKeys: String, CodingKey {
        case contents
        case totalPages = "total_pages"
    }
}

class ArenaAPIService {
    private let urlSession: URLSession
    private let baseURL = "https://api.are.na/v2"
    private let rateLimitTracker: RateLimitTracker
    private let tokenStorage: TokenStorage

    init(
        urlSession: URLSession = .shared,
        rateLimitTracker: RateLimitTracker,
        tokenStorage: TokenStorage
    ) {
        self.urlSession = urlSession
        self.rateLimitTracker = rateLimitTracker
        self.tokenStorage = tokenStorage
    }

    private func performRequest(url: URL) async throws -> (Data, HTTPURLResponse) {
        await MainActor.run {
            rateLimitTracker.resetWindowIfExpired()
        }

        let remaining = await MainActor.run { rateLimitTracker.remainingRequests }
        if remaining <= 0 {
            throw APIError.rateLimitExceeded
        }

        await MainActor.run {
            rateLimitTracker.recordRequest()
        }

        var request = URLRequest(url: url)
        if let token = tokenStorage.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        await MainActor.run {
            rateLimitTracker.updateFromResponse(httpResponse, hasToken: tokenStorage.hasToken)
        }

        return (data, httpResponse)
    }

    /// Are.na returns 400 "Attributes per element limit exceeded" when paginating too far.
    /// Cap at 40 pages to avoid hitting this server-side limit.
    private static let maxBlockSearchPages = 40

    func fetchBlocks(for query: String, startPage: Int = 1) async throws -> [ArenaBlock] {
        var allBlocks: [ArenaBlock] = []
        var page = startPage
        var totalPages = 1

        while page <= totalPages, page <= Self.maxBlockSearchPages {
            do {
                let pageBlocks = try await fetchBlocksPage(query: query, page: page)
                allBlocks.append(contentsOf: pageBlocks.blocks)
                totalPages = pageBlocks.totalPages
                page += 1
            } catch APIError.httpError(400, _) {
                print("⚠️ API limit reached at block search page \(page), returning \(allBlocks.count) blocks")
                break
            }
        }

        return allBlocks
    }

    func fetchBlocksPage(query: String, page: Int) async throws -> (blocks: [ArenaBlock], totalPages: Int) {
        let urlString =
            "\(baseURL)/search/blocks?q="
                + (query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
                + "&page=\(page)"

        guard let url = URL(string: urlString) else {
            return ([], 1)
        }

        let (data, httpResponse) = try await performRequest(url: url)

        print("📡 API Response: \(httpResponse.statusCode) for blocks page \(page)")

        if httpResponse.statusCode == 429 {
            print("⚠️ Rate limit exceeded at block search page \(page)")
            throw APIError.rateLimitExceeded
        }
        if httpResponse.statusCode != 200 {
            let responseString = String(data: data, encoding: .utf8) ?? "No response body"
            throw APIError.httpError(httpResponse.statusCode, responseString)
        }

        let decoded = try JSONDecoder().decode(ArenaBlockSearchResponse.self, from: data)
        return (decoded.blocks, decoded.totalPages ?? 1)
    }

    func fetchChannels(for blockID: Int) async throws -> [ArenaChannel] {
        var allChannels: [ArenaChannel] = []
        var page = 1
        var totalPages = 1

        while page <= totalPages {
            let result = try await fetchChannelsPage(blockID: blockID, page: page)
            allChannels.append(contentsOf: result.channels)
            totalPages = result.totalPages
            if totalPages == 0 { break }
            page += 1
        }

        return allChannels
    }

    func fetchChannelsPage(blockID: Int, page: Int) async throws -> (channels: [ArenaChannel], totalPages: Int) {
        let urlString = "\(baseURL)/blocks/\(blockID)/channels?page=\(page)"
        guard let url = URL(string: urlString) else {
            return ([], 1)
        }

        let (data, httpResponse) = try await performRequest(url: url)

        if httpResponse.statusCode == 429 {
            print("⚠️ Rate limit exceeded at block \(blockID) channels page \(page)")
            throw APIError.rateLimitExceeded
        }
        if httpResponse.statusCode == 401 {
            return ([], 1)
        }
        if httpResponse.statusCode != 200 {
            let responseString = String(data: data, encoding: .utf8) ?? "No response body"
            throw APIError.httpError(httpResponse.statusCode, responseString)
        }

        let decoded = try JSONDecoder().decode(ArenaChannelResponse.self, from: data)
        return (decoded.channels, decoded.totalPages ?? 1)
    }

    func fetchChannelContents(slug: String) async throws -> [ArenaBlock] {
        var allContents: [ArenaBlock] = []
        var page = 1
        var totalPages = 1

        while page <= totalPages {
            let result = try await fetchChannelContentsPage(slug: slug, page: page)
            let linkBlocks = result.contents.filter { $0.blockClass == "Link" }
            allContents.append(contentsOf: linkBlocks)
            totalPages = result.totalPages
            page += 1
        }

        return allContents
    }

    /// Fetches only the first page of channel contents. Use when prioritizing URL discovery
    /// over completeness to conserve rate limit.
    func fetchChannelContentsFirstPage(slug: String) async throws -> [ArenaBlock] {
        let result = try await fetchChannelContentsPage(slug: slug, page: 1)
        return result.contents.filter { $0.blockClass == "Link" }
    }

    func fetchChannelContentsPage(slug: String, page: Int) async throws -> (contents: [ArenaBlock], totalPages: Int) {
        let urlString = "\(baseURL)/channels/\(slug)/contents?page=\(page)"
        guard let url = URL(string: urlString) else {
            return ([], 1)
        }

        let (data, httpResponse) = try await performRequest(url: url)

        if httpResponse.statusCode == 429 {
            print("⚠️ Rate limit exceeded at channel \(slug) contents page \(page)")
            throw APIError.rateLimitExceeded
        }
        if httpResponse.statusCode == 401 {
            return ([], 0)
        }
        if httpResponse.statusCode != 200 {
            let responseString = String(data: data, encoding: .utf8) ?? "No response body"
            throw APIError.httpError(httpResponse.statusCode, responseString)
        }

        let decoded = try JSONDecoder().decode(ArenaChannelContentsResponse.self, from: data)
        return (decoded.contents, decoded.totalPages ?? 1)
    }
}
