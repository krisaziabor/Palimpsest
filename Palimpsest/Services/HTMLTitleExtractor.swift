import Foundation
import SwiftSoup

enum HTMLTitleExtractionError: Error {
    case invalidURL
    case networkError(Error)
    case parsingError(Error)
    case noTitleFound
    case emptyTitle

    var localizedDescription: String {
        switch self {
        case .invalidURL:
            "Invalid URL provided"
        case let .networkError(error):
            "Network error: \(error.localizedDescription)"
        case let .parsingError(error):
            "HTML parsing error: \(error.localizedDescription)"
        case .noTitleFound:
            "No title tag found in HTML"
        case .emptyTitle:
            "Title tag is empty"
        }
    }
}

class HTMLTitleExtractor {
    private let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    /// Extracts the title from a webpage by making an HTTP request and parsing the HTML
    /// - Parameter urlString: The URL to extract the title from
    /// - Returns: The cleaned title text from the webpage
    func extractTitle(from urlString: String) async throws -> String {
        guard let url = URL(string: urlString) else {
            throw HTMLTitleExtractionError.invalidURL
        }

        do {
            // Create request with appropriate headers
            var request = URLRequest(url: url)
            request.setValue(
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
                forHTTPHeaderField: "User-Agent"
            )
            request.setValue(
                "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                forHTTPHeaderField: "Accept"
            )
            request.timeoutInterval = 10.0

            let (data, _) = try await urlSession.data(for: request)

            // Convert data to string
            guard let htmlString = String(data: data, encoding: .utf8) else {
                throw HTMLTitleExtractionError.parsingError(NSError(
                    domain: "HTMLTitleExtractor",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to decode HTML as UTF-8"]
                ))
            }

            // Parse HTML and extract title
            let document = try SwiftSoup.parse(htmlString)
            guard let titleElement = try document.select("title").first() else {
                throw HTMLTitleExtractionError.noTitleFound
            }

            let title = try titleElement.text().trimmingCharacters(in: .whitespacesAndNewlines)

            guard !title.isEmpty else {
                throw HTMLTitleExtractionError.emptyTitle
            }

            return cleanTitle(title)

        } catch let error as HTMLTitleExtractionError {
            throw error
        } catch {
            throw HTMLTitleExtractionError.networkError(error)
        }
    }

    /// Cleans the title by removing common suffixes and unnecessary characters
    /// - Parameter title: The raw title from the webpage
    /// - Returns: A cleaned title suitable for searching
    private func cleanTitle(_ title: String) -> String {
        var cleaned = title

        // Common site suffixes to remove
        let suffixesToRemove = [
            " - Blog",
            " | Blog",
            " - Official Site",
            " | Official Site",
            " - Home",
            " | Home",
            " - Homepage",
            " | Homepage",
        ]

        // Remove common suffixes
        for suffix in suffixesToRemove where cleaned.hasSuffix(suffix) {
            cleaned = String(cleaned.dropLast(suffix.count))
            break
        }

        // Remove excessive whitespace
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
