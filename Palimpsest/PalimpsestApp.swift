//
//  PalimpsestApp.swift
//  Palimpsest
//
//  Created by kris aziabor on 7/1/25.
//

import SwiftUI

private final class SearchServiceHolder: ObservableObject {
    let searchService: SearchService

    init(rateLimitTracker: RateLimitTracker, tokenStorage: TokenStorage) {
        let arenaAPI = ArenaAPIService(
            rateLimitTracker: rateLimitTracker,
            tokenStorage: tokenStorage
        )
        searchService = SearchService(arenaAPIService: arenaAPI)
    }
}

@main
struct PalimpsestApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var collectionManager: CollectionManager
    @StateObject private var transferManager: TransferManager
    @StateObject private var hardDriveModeManager: HardDriveModeManager
    private let tokenStorage: TokenStorage
    private let driveSettings: DriveSettingsStorage
    @StateObject private var rateLimitTracker: RateLimitTracker
    @StateObject private var searchServiceHolder: SearchServiceHolder

    init() {
        let storage = TokenStorage()
        let tracker = RateLimitTracker()
        let drive = DriveSettingsStorage()
        let collection = CollectionManager()

        tokenStorage = storage
        driveSettings = drive
        _collectionManager = StateObject(wrappedValue: collection)
        _hardDriveModeManager = StateObject(wrappedValue: HardDriveModeManager())
        _rateLimitTracker = StateObject(wrappedValue: tracker)
        _searchServiceHolder = StateObject(wrappedValue: SearchServiceHolder(
            rateLimitTracker: tracker,
            tokenStorage: storage
        ))
        _transferManager = StateObject(wrappedValue: TransferManager(
            driveSettings: drive,
            collectionManager: collection
        ))
    }

    var body: some Scene {
        WindowGroup {
            MainNavigationView(
                searchService: searchServiceHolder.searchService,
                tokenStorage: tokenStorage,
                driveSettings: driveSettings
            )
            .environmentObject(collectionManager)
            .environmentObject(transferManager)
            .environmentObject(hardDriveModeManager)
            .environmentObject(rateLimitTracker)
        }
    }
}
