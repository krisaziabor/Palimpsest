//
//  TransferManager.swift
//  Constellating
//
//  Handles weekly transfer of saved items to the configured hard drive.
//

import Foundation

enum TransferError: Error {
    case driveNotFound
    case palimpsestFolderNotFound
    case transferFailed(String)
}

@MainActor
final class TransferManager: ObservableObject {
    private let driveSettings: DriveSettingsStorage
    private let collectionManager: CollectionManager

    init(driveSettings: DriveSettingsStorage = DriveSettingsStorage(), collectionManager: CollectionManager) {
        self.driveSettings = driveSettings
        self.collectionManager = collectionManager
    }

    func performTransfer() async throws {
        guard let driveName = driveSettings.driveName, !driveName.isEmpty else {
            throw TransferError.transferFailed("No drive configured in Settings.")
        }

        // Get the drive URL
        guard let volumeURL = driveSettings.resolveDriveURL() else {
            throw TransferError.transferFailed("Drive not found. Please reconfigure in Settings.")
        }

        // Start accessing the security-scoped resource
        let didStartAccessing = volumeURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                volumeURL.stopAccessingSecurityScopedResource()
            }
        }

        guard FileManager.default.fileExists(atPath: volumeURL.path) else {
            throw TransferError.driveNotFound
        }

        let palimpsestURL = volumeURL.appendingPathComponent("Palimpsest", isDirectory: true)
        if !FileManager.default.fileExists(atPath: palimpsestURL.path) {
            try FileManager.default.createDirectory(at: palimpsestURL, withIntermediateDirectories: true)
        }

        let week = WeekFormatter.weekString()
        let weekURL = palimpsestURL.appendingPathComponent(week, isDirectory: true)
        if !FileManager.default.fileExists(atPath: weekURL.path) {
            try FileManager.default.createDirectory(at: weekURL, withIntermediateDirectories: true)
        }

        let itemsToTransfer = collectionManager.items.filter { !$0.isTransferred }

        for item in itemsToTransfer {
            try transferItem(item, to: weekURL)
        }

        collectionManager.markAsTransferred(
            ids: itemsToTransfer.map(\.id),
            transferWeek: week,
            driveName: driveName
        )
    }

    private func transferItem(_ item: SavedItem, to weekURL: URL) throws {
        let itemFolder = weekURL.appendingPathComponent(item.id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: itemFolder, withIntermediateDirectories: true)

        if FileManager.default.fileExists(atPath: item.audioFilePath) {
            let audioDest = itemFolder.appendingPathComponent("recording.m4a")
            try FileManager.default.copyItem(
                at: URL(fileURLWithPath: item.audioFilePath),
                to: audioDest
            )
        }

        if !item.mediaFilePaths.isEmpty {
            let mediaFolder = itemFolder.appendingPathComponent("media", isDirectory: true)
            try FileManager.default.createDirectory(at: mediaFolder, withIntermediateDirectories: true)
            for (index, mediaPath) in item.mediaFilePaths.enumerated() {
                guard FileManager.default.fileExists(atPath: mediaPath) else { continue }
                let mediaURL = URL(fileURLWithPath: mediaPath)
                let ext = mediaURL.pathExtension.isEmpty ? "file" : mediaURL.pathExtension
                let destURL = mediaFolder.appendingPathComponent("media_\(index).\(ext)")
                try FileManager.default.copyItem(at: mediaURL, to: destURL)
            }
        }

        let metadata: [String: Any] = [
            "sourceTitle": item.sourceTitle,
            "sourceURL": item.sourceURL,
            "transcription": item.transcription,
            "savedAt": ISO8601DateFormatter().string(from: item.savedAt),
            "mediaCount": item.mediaFilePaths.count,
        ]
        let metadataData = try JSONSerialization.data(withJSONObject: metadata)
        try metadataData.write(to: itemFolder.appendingPathComponent("metadata.json"))
    }

    var hasTransferredItems: Bool {
        collectionManager.hasTransferredItems
    }
}
