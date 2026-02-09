import SwiftUI

// swiftlint:disable line_length
private let palimpsestDefinition = """
palimpsest /ˈpalɪm(p)sɛst/ noun. A manuscript or surface on which the original writing has been effaced to make room for later writing, but of which traces remain. From Greek palimpsēstos, "scraped again" — palin (again) + psēstos (rubbed smooth). The word names a paradox: something must be destroyed for something new to exist, yet the destroyed thing refuses to fully disappear.
"""

private let palimpsestAppDescription = """
In this tool, every design source you collect is a palimpsest in progress. You see it clearly, you speak over it, and time scrapes the original away — leaving only a blurred trace beneath your own voice. What remains is not what you found but what you said when you found it. The sources fade. Your thinking stays.
"""
// swiftlint:enable line_length

// swiftlint:disable:next type_body_length
struct ArenaBlockSearchView: View {
    @EnvironmentObject private var rateLimitTracker: RateLimitTracker
    @EnvironmentObject private var collectionManager: CollectionManager
    @EnvironmentObject private var hardDriveModeManager: HardDriveModeManager
    @State private var inputURL: String = ""
    @State private var isLoading: Bool = false
    @State private var exactCount: Int = 0
    @State private var inexactCount: Int = 0
    @State private var errorMessage: String?
    @State private var foundChannels: [ArenaChannel] = []
    @State private var discoveredURLs: [DiscoveredURL] = []
    @State private var classifiedBlocks: [ClassifiedBlock] = []
    @State private var isBlocksExpanded: Bool = false
    @State private var isChannelsExpanded: Bool = false
    @State private var isOtherWebsitesExpanded: Bool = true
    @State private var showBlocksAndChannels: Bool = false
    @State private var resumeState: SearchResumeState?
    @State private var isRateLimited: Bool = false

    let searchService: SearchService

    private var hasSearchResults: Bool {
        !discoveredURLs.isEmpty || !classifiedBlocks.isEmpty || !foundChannels.isEmpty
    }

    private var isSearchDisabled: Bool {
        collectionManager.isLockedOut || hardDriveModeManager.isSearchLockedOut
    }

    private var transferredMessage: String? {
        guard !inputURL.isEmpty else { return nil }
        if let info = collectionManager.transferredInfo(for: inputURL) {
            return "This URL is on the hard drive in \(info.week) (\(info.drive))."
        }
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Spacer(minLength: 20)

                Text("Palimpsest")
                    .font(LectorFont.largeTitle)

                Text(palimpsestDefinition)
                    .font(LectorFont.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(palimpsestAppDescription)
                    .font(LectorFont.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 32)

                if let lockoutMsg = collectionManager.lockoutMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.orange)
                        Text(lockoutMsg)
                            .font(LectorFont.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        Text("Go to Collection → Transfer to Drive")
                            .font(LectorFont.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(32)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                }

                if collectionManager.lockoutMessage == nil,
                   let hdmMessage = hardDriveModeManager.searchLockoutMessage
                {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.badge.exclamationmark")
                            .font(.system(size: 32))
                            .foregroundColor(.purple)
                        Text(hdmMessage)
                            .font(LectorFont.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        if hardDriveModeManager.isInHardDriveMode {
                            Text("You're in Hard Drive Mode. Explore your archive or wait until tomorrow.")
                                .font(LectorFont.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(32)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(12)
                }

                if let msg = transferredMessage {
                    HStack {
                        Image(systemName: "externaldrive.fill")
                            .foregroundColor(.accentColor)
                        Text(msg)
                            .font(LectorFont.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
                }

                if isRateLimited {
                    Text("Rate limit exceeded. Partial results shown below. Wait a minute, then tap Continue Search.")
                        .font(LectorFont.caption)
                        .foregroundColor(.orange)
                }

                if rateLimitTracker.shouldWarn, !isRateLimited {
                    if rateLimitTracker.remainingRequests == 0 {
                        Text("Rate limit reached. One more search may hit the limit. "
                            + "Resets in \(rateLimitTracker.secondsUntilReset)s."
                        )
                        .font(LectorFont.caption)
                        .foregroundColor(.orange)
                    } else {
                        Text("Approaching rate limit: \(rateLimitTracker.remainingRequests) requests left this minute. "
                            + "Resets in \(rateLimitTracker.secondsUntilReset)s."
                        )
                        .font(LectorFont.caption)
                        .foregroundColor(.orange)
                    }
                }

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                }

                if hasSearchResults {
                    HStack {
                        Text("Exact matches: \(exactCount)")
                        Text("Inexact matches: \(inexactCount)")
                    }
                    .font(LectorFont.headline)

                    VStack(spacing: 16) {
                        OtherWebsitesSectionView(
                            discoveredURLs: discoveredURLs,
                            isExpanded: $isOtherWebsitesExpanded
                        )

                        DisclosureGroup(
                            isExpanded: $showBlocksAndChannels,
                            content: {
                                BlocksSectionView(
                                    classifiedBlocks: classifiedBlocks,
                                    isExpanded: $isBlocksExpanded
                                )
                                ChannelsSectionView(
                                    channels: foundChannels,
                                    isExpanded: $isChannelsExpanded
                                )
                            },
                            label: {
                                Text(
                                    "Blocks & Channels (\(classifiedBlocks.count) blocks, "
                                        + "\(foundChannels.count) channels)"
                                )
                                .font(LectorFont.headline)
                                .foregroundColor(.secondary)
                            }
                        )
                    }
                }

                Spacer(minLength: 24)

                HStack(spacing: 12) {
                    TextField("Enter a URL", text: $inputURL)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(isSearchDisabled)
                    Button(action: {
                        if resumeState != nil {
                            continueSearch()
                        } else {
                            searchBlocks()
                        }
                    }, label: {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text(resumeState != nil ? "Continue Search" : "Search")
                        }
                    })
                    .disabled((inputURL.isEmpty && resumeState == nil) || isLoading || isSearchDisabled)
                }
                .padding(.horizontal)
            }
            .padding()
        }
    }

    func searchBlocks() {
        guard URL(string: inputURL) != nil else {
            errorMessage = "Invalid URL"
            return
        }
        resetSearchState()
        isRateLimited = false
        isLoading = true
        errorMessage = nil

        Task {
            await runSearch(resume: nil)
        }
    }

    private func continueSearch() {
        guard let state = resumeState else { return }
        isLoading = true
        errorMessage = nil

        Task {
            await runSearch(resume: state)
        }
    }

    @MainActor
    private func runSearch(resume: SearchResumeState?) async {
        do {
            let urlToSearch = resume?.originalURL ?? inputURL
            let outcome = try await searchService.performDualSearch(
                originalURL: urlToSearch,
                resumeState: resume,
                onProgress: { results in
                    Task { @MainActor in
                        updateUI(with: results)
                    }
                }
            )

            switch outcome {
            case let .complete(results):
                updateUI(with: results)
                resumeState = nil
                isRateLimited = false
                isLoading = false

            case let .rateLimited(partial, state):
                updateUI(with: partial)
                resumeState = state
                isRateLimited = true
                isLoading = false
            }
        } catch {
            handleSearchError(error)
            isLoading = false
        }
    }

    private func resetSearchState() {
        exactCount = 0
        inexactCount = 0
        foundChannels = []
        discoveredURLs = []
        classifiedBlocks = []
        resumeState = nil
    }

    @MainActor
    private func updateUI(with results: SearchResults) {
        exactCount = results.exactCount
        inexactCount = results.inexactCount
        foundChannels = results.channels
        discoveredURLs = results.discoveredURLs
        classifiedBlocks = results.classifiedBlocks
    }

    @MainActor
    private func handleSearchError(_ error: Error) {
        errorMessage = error.localizedDescription
    }
}
