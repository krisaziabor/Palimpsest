//
//  MainNavigationView.swift
//  Constellating
//
//  Root navigation: Search, Collection, and Archive (when in Hard Drive Mode).
//

import SwiftUI

enum NavigationSection: String, CaseIterable {
    case search = "Search"
    case collection = "Collection"
    case archive = "Archive"
    case settings = "Settings"

    static func visibleCases(isInHardDriveMode: Bool) -> [NavigationSection] {
        if isInHardDriveMode {
            [.search, .collection, .archive, .settings]
        } else {
            [.search, .collection, .settings]
        }
    }
}

struct MainNavigationView: View {
    @State private var selectedSection: NavigationSection = .search
    @EnvironmentObject private var hardDriveModeManager: HardDriveModeManager

    let searchService: SearchService
    let tokenStorage: TokenStorage
    let driveSettings: DriveSettingsStorage

    private var visibleSections: [NavigationSection] {
        NavigationSection.visibleCases(isInHardDriveMode: hardDriveModeManager.isInHardDriveMode)
    }

    var body: some View {
        NavigationSplitView {
            List(visibleSections, id: \.self, selection: $selectedSection) { section in
                NavigationLink(value: section) {
                    Label(
                        section.rawValue,
                        systemImage: iconForSection(section)
                    )
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            switch selectedSection {
            case .search:
                ArenaBlockSearchView(searchService: searchService)
            case .collection:
                CollectionView()
            case .archive:
                ArchiveBrowserView()
            case .settings:
                SettingsView(tokenStorage: tokenStorage, driveSettings: driveSettings)
            }
        }
        .sheet(isPresented: Binding(
            get: { hardDriveModeManager.showDriveDetectedPrompt },
            set: { if !$0 { hardDriveModeManager.dismissPrompt() } }
        )) {
            HardDriveModePromptView()
        }
        .onAppear {
            hardDriveModeManager.startMonitoringVolumes()
        }
        .onDisappear {
            hardDriveModeManager.stopMonitoringVolumes()
        }
        .onChange(of: hardDriveModeManager.isInHardDriveMode) { _, isInMode in
            if !isInMode, selectedSection == .archive {
                selectedSection = .search
            }
        }
    }

    private func iconForSection(_ section: NavigationSection) -> String {
        switch section {
        case .search: "magnifyingglass"
        case .collection: "bookmark.fill"
        case .archive: "externaldrive.fill"
        case .settings: "gearshape"
        }
    }
}
