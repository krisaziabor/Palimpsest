//
//  HardDriveModeManager.swift
//  Constellating
//
//  Manages Hard Drive Mode state and search lockout.
//

import Foundation
import SwiftUI

@MainActor
final class HardDriveModeManager: ObservableObject {
    @Published private(set) var isInHardDriveMode: Bool = false
    @Published private(set) var connectedDriveName: String?
    @Published private(set) var connectedDriveURL: URL?
    @Published private(set) var showDriveDetectedPrompt: Bool = false
    @Published private(set) var archiveWeeks: [ArchiveWeek] = []

    private let lockoutKey = "hardDriveModeLockoutDate"
    private let archiveFolderName = "Palimpsest"
    private var volumeObserver: Any?

    // MARK: - Lockout Logic

    /// Returns true if search should be disabled due to Hard Drive Mode lockout
    var isSearchLockedOut: Bool {
        guard let lockoutDate = UserDefaults.standard.object(forKey: lockoutKey) as? Date else {
            return false
        }
        // Lockout expires at midnight
        let calendar = Calendar.current
        let endOfLockoutDay = calendar.startOfDay(for: lockoutDate).addingTimeInterval(24 * 60 * 60)
        return Date() < endOfLockoutDay
    }

    var lockoutExpiresAt: Date? {
        guard let lockoutDate = UserDefaults.standard.object(forKey: lockoutKey) as? Date else {
            return nil
        }
        let calendar = Calendar.current
        return calendar.startOfDay(for: lockoutDate).addingTimeInterval(24 * 60 * 60)
    }

    var searchLockoutMessage: String? {
        guard isSearchLockedOut else { return nil }
        if let expires = lockoutExpiresAt {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Hard Drive Mode active. New searches available after midnight (\(formatter.string(from: expires)))."
        }
        return "Hard Drive Mode active. New searches disabled until tomorrow."
    }

    // MARK: - Drive Detection

    func startMonitoringVolumes() {
        volumeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didMountNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleVolumeMounted(notification)
            }
        }

        checkMountedVolumes()
    }

    func stopMonitoringVolumes() {
        if let observer = volumeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    private func handleVolumeMounted(_ notification: Notification) {
        guard let volumeURL = notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL else {
            return
        }
        checkForPalimpsestFolder(at: volumeURL)
    }

    private func checkMountedVolumes() {
        let volumesURL = URL(fileURLWithPath: "/Volumes")
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: volumesURL,
            includingPropertiesForKeys: nil
        ) else { return }

        for volumeURL in contents {
            checkForPalimpsestFolder(at: volumeURL)
        }
    }

    private func checkForPalimpsestFolder(at volumeURL: URL) {
        let palimpsestURL = volumeURL.appendingPathComponent(archiveFolderName, isDirectory: true)
        var isDirectory: ObjCBool = false

        if FileManager.default.fileExists(atPath: palimpsestURL.path, isDirectory: &isDirectory),
           isDirectory.boolValue
        {
            connectedDriveName = volumeURL.lastPathComponent
            connectedDriveURL = volumeURL

            if !isSearchLockedOut, !isInHardDriveMode {
                showDriveDetectedPrompt = true
            }
        }
    }

    // MARK: - Mode Control

    func enterHardDriveMode() {
        guard let driveURL = connectedDriveURL else { return }

        UserDefaults.standard.set(Date(), forKey: lockoutKey)

        loadArchiveContents(from: driveURL)

        isInHardDriveMode = true
        showDriveDetectedPrompt = false
    }

    func dismissPrompt() {
        showDriveDetectedPrompt = false
    }

    func exitHardDriveMode() {
        isInHardDriveMode = false
        archiveWeeks = []
    }

    // MARK: - Archive Loading

    private func loadArchiveContents(from driveURL: URL) {
        let palimpsestURL = driveURL.appendingPathComponent(archiveFolderName, isDirectory: true)

        guard let weekFolders = try? FileManager.default.contentsOfDirectory(
            at: palimpsestURL,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else {
            archiveWeeks = []
            return
        }

        var weeks: [ArchiveWeek] = []

        for weekURL in weekFolders {
            guard let resourceValues = try? weekURL.resourceValues(forKeys: [.isDirectoryKey]),
                  resourceValues.isDirectory == true else { continue }

            let weekName = weekURL.lastPathComponent
            var items: [ArchivedItem] = []

            if let itemFolders = try? FileManager.default.contentsOfDirectory(
                at: weekURL,
                includingPropertiesForKeys: [.isDirectoryKey]
            ) {
                for itemURL in itemFolders {
                    if let item = loadArchivedItem(from: itemURL) {
                        items.append(item)
                    }
                }
            }

            if !items.isEmpty {
                weeks.append(ArchiveWeek(name: weekName, folderURL: weekURL, items: items))
            }
        }

        archiveWeeks = weeks.sorted { $0.name > $1.name }
    }

    private func loadArchivedItem(from folderURL: URL) -> ArchivedItem? {
        let metadataURL = folderURL.appendingPathComponent("metadata.json")

        guard let metadataData = try? Data(contentsOf: metadataURL),
              let metadata = try? JSONSerialization.jsonObject(with: metadataData) as? [String: Any]
        else {
            return nil
        }

        let audioURL = folderURL.appendingPathComponent("recording.m4a")
        let mediaFolderURL = folderURL.appendingPathComponent("media", isDirectory: true)

        var mediaURLs: [URL] = []
        if let mediaContents = try? FileManager.default.contentsOfDirectory(
            at: mediaFolderURL,
            includingPropertiesForKeys: nil
        ) {
            mediaURLs = mediaContents.filter { url in
                let ext = url.pathExtension.lowercased()
                return ["png", "jpg", "jpeg", "gif", "mov", "mp4"].contains(ext)
            }
        }

        return ArchivedItem(
            id: folderURL.lastPathComponent,
            folderURL: folderURL,
            sourceTitle: metadata["sourceTitle"] as? String ?? "Untitled",
            sourceURL: metadata["sourceURL"] as? String ?? "",
            transcription: metadata["transcription"] as? String ?? "",
            savedAt: ISO8601DateFormatter().date(from: metadata["savedAt"] as? String ?? "") ?? Date(),
            audioURL: FileManager.default.fileExists(atPath: audioURL.path) ? audioURL : nil,
            mediaURLs: mediaURLs
        )
    }
}

// MARK: - Models

struct ArchiveWeek: Identifiable {
    let id = UUID()
    let name: String
    let folderURL: URL
    let items: [ArchivedItem]
}

struct ArchivedItem: Identifiable {
    let id: String
    let folderURL: URL
    let sourceTitle: String
    let sourceURL: String
    let transcription: String
    let savedAt: Date
    let audioURL: URL?
    let mediaURLs: [URL]
}
