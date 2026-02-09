//
//  CollectionManager.swift
//  Palimpsest
//
//  Manages saved items with voice recordings. Uses JSON file storage.
//

import Foundation
import SwiftUI

@MainActor
final class CollectionManager: ObservableObject {
    @Published private(set) var items: [SavedItem] = []
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// All items in the collection (including transferred).
    var allItems: [SavedItem] {
        items
    }

    /// Items not yet transferred (used by transfer logic and button state).
    var untransferredItems: [SavedItem] {
        items.filter { !$0.isTransferred }
    }

    var hasTransferredItems: Bool {
        items.contains { $0.isTransferred }
    }

    init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = documentsPath.appendingPathComponent("collection.json", isDirectory: false)
        loadItems()
    }

    func add(_ item: SavedItem) {
        items.insert(item, at: 0)
        saveItems()
    }

    func remove(_ item: SavedItem) {
        items.removeAll { $0.id == item.id }
        saveItems()
    }

    func markAsTransferred(ids: [UUID], transferWeek: String, driveName: String) {
        let now = Date()
        for id in ids {
            if let index = items.firstIndex(where: { $0.id == id }) {
                let item = items[index]
                items[index] = SavedItem(
                    id: item.id,
                    sourceTitle: item.sourceTitle,
                    sourceURL: item.sourceURL,
                    audioFilePath: item.audioFilePath,
                    transcription: item.transcription,
                    savedAt: item.savedAt,
                    transferredAt: now,
                    transferWeek: transferWeek,
                    driveName: driveName,
                    mediaFilePaths: item.mediaFilePaths
                )
            }
        }
        saveItems()
    }

    /// Returns true if the app should be locked due to missed transfer.
    var isLockedOut: Bool {
        let untransferred = items.filter { !$0.isTransferred }
        guard !untransferred.isEmpty else { return false }

        guard let oldest = untransferred.min(by: { $0.savedAt < $1.savedAt }) else {
            return false
        }

        let calendar = Calendar.current
        let now = Date()

        guard let sunday = calendar.nextDate(
            after: now,
            matching: DateComponents(weekday: 1),
            matchingPolicy: .previousTimePreservingSmallerComponents,
            direction: .backward
        ) else {
            return false
        }
        let mostRecentSunday = calendar.startOfDay(for: sunday)

        return oldest.savedAt < mostRecentSunday
    }

    var lockoutMessage: String? {
        guard isLockedOut else { return nil }
        let count = items.filter { !$0.isTransferred }.count
        let plural = count == 1 ? "" : "s"
        return "Transfer required: \(count) item\(plural) from last week. Complete transfer to continue."
    }

    func addMedia(to itemId: UUID, filePath: String) {
        guard let index = items.firstIndex(where: { $0.id == itemId }) else { return }
        let item = items[index]
        var newMediaPaths = item.mediaFilePaths
        newMediaPaths.append(filePath)

        items[index] = SavedItem(
            id: item.id,
            sourceTitle: item.sourceTitle,
            sourceURL: item.sourceURL,
            audioFilePath: item.audioFilePath,
            transcription: item.transcription,
            savedAt: item.savedAt,
            transferredAt: item.transferredAt,
            transferWeek: item.transferWeek,
            driveName: item.driveName,
            mediaFilePaths: newMediaPaths
        )
        saveItems()
    }

    /// Copies the file to app storage and adds it to the item. Ensures dropped/picked files
    /// persist until transfer even if the original is moved or deleted.
    func addMediaFromURL(to itemId: UUID, sourceURL: URL) {
        guard items.contains(where: { $0.id == itemId }) else { return }
        guard sourceURL.isFileURL else { return }

        let baseURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let mediaRoot = baseURL.appendingPathComponent("collection_media", isDirectory: true)
        let itemFolder = mediaRoot.appendingPathComponent(itemId.uuidString, isDirectory: true)

        do {
            if !FileManager.default.fileExists(atPath: itemFolder.path) {
                try FileManager.default.createDirectory(at: itemFolder, withIntermediateDirectories: true)
            }
            let ext = sourceURL.pathExtension.isEmpty ? "file" : sourceURL.pathExtension
            let destName = "\(UUID().uuidString).\(ext)"
            let destURL = itemFolder.appendingPathComponent(destName)
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            addMedia(to: itemId, filePath: destURL.path)
        } catch {
            // Non-fatal: user can try again
        }
    }

    /// Copies a file to app storage for an item. Call from drop handler (which may run off main).
    /// Returns the destination path on success; add the path via addMedia afterward.
    static func copyMediaToStorage(itemId: UUID, sourceURL: URL) -> String? {
        guard sourceURL.isFileURL else { return nil }
        guard FileManager.default.fileExists(atPath: sourceURL.path) else { return nil }

        let baseURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let mediaRoot = baseURL.appendingPathComponent("collection_media", isDirectory: true)
        let itemFolder = mediaRoot.appendingPathComponent(itemId.uuidString, isDirectory: true)

        do {
            if !FileManager.default.fileExists(atPath: itemFolder.path) {
                try FileManager.default.createDirectory(at: itemFolder, withIntermediateDirectories: true)
            }
            let ext = sourceURL.pathExtension.isEmpty ? "file" : sourceURL.pathExtension
            let destName = "\(UUID().uuidString).\(ext)"
            let destURL = itemFolder.appendingPathComponent(destName)
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            return destURL.path
        } catch {
            return nil
        }
    }

    func transferredInfo(for url: String) -> (week: String, drive: String)? {
        for item in items where item.isTransferred {
            let (matches, _) = urlsMatch(url, item.sourceURL)
            if matches, let week = item.transferWeek, let drive = item.driveName {
                return (week, drive)
            }
        }
        return nil
    }

    private func loadItems() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            decoder.dateDecodingStrategy = .iso8601
            let data = try Data(contentsOf: fileURL)
            items = try decoder.decode([SavedItem].self, from: data)
        } catch {
            // Non-fatal: start with empty collection
        }
    }

    private func saveItems() {
        do {
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(items)
            try data.write(to: fileURL)
        } catch {
            // Non-fatal: items remain in memory
        }
    }
}
