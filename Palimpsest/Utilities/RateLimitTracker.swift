//
//  RateLimitTracker.swift
//  Palimpsest
//
//  Tracks Are.na API rate limit from response headers; falls back to client-side counting.
//

import Foundation

@MainActor
final class RateLimitTracker: ObservableObject {
    @Published private(set) var limit: Int = 30
    @Published private(set) var requestsInWindow: Int = 0
    @Published private(set) var resetTimestamp: TimeInterval = 0
    @Published private(set) var tier: String = "guest"

    private let warnThreshold = 5

    var remainingRequests: Int {
        max(0, limit - requestsInWindow)
    }

    var shouldWarn: Bool {
        remainingRequests <= warnThreshold && remainingRequests >= 0
    }

    var secondsUntilReset: Int {
        let now = Date().timeIntervalSince1970
        return max(0, Int(resetTimestamp - now))
    }

    /// Call before each API request. Increments count; resets if window expired.
    func recordRequest() {
        let now = Date().timeIntervalSince1970
        if resetTimestamp > 0, now > resetTimestamp {
            requestsInWindow = 0
        }
        requestsInWindow += 1
    }

    /// Call after each API response (including 429). Parses headers and updates state.
    /// - Parameters:
    ///   - response: The HTTP response
    ///   - hasToken: When true and headers missing, assume Premium (300). When false, assume Guest (30).
    func updateFromResponse(_ response: HTTPURLResponse, hasToken: Bool) {
        let headerLimit = Int(response.value(forHTTPHeaderField: "X-RateLimit-Limit") ?? "")
        let headerResetString = response.value(forHTTPHeaderField: "X-RateLimit-Reset")
        let headerReset = headerResetString.flatMap { Double($0) }
        let headerTier = response.value(forHTTPHeaderField: "X-RateLimit-Tier")

        if let lim = headerLimit {
            limit = lim
        } else {
            limit = hasToken ? 300 : 30
        }

        if let tierValue = headerTier {
            tier = tierValue
        }

        if let reset = headerReset, reset > 0 {
            resetTimestamp = reset
        } else {
            resetTimestamp = Date().timeIntervalSince1970 + 60
        }

        if headerLimit == nil {
            requestsInWindow = min(requestsInWindow, limit)
        }
    }

    /// Reset client-side window when no headers available (e.g. first request).
    func resetWindowIfExpired() {
        let now = Date().timeIntervalSince1970
        if resetTimestamp > 0, now > resetTimestamp {
            requestsInWindow = 0
        }
    }

    /// Set assumed limit when authenticated but no headers yet. Call when token changes.
    func setAssumedLimit(_ lim: Int) {
        limit = lim
    }
}
