//
//  DriveSettingsStorage.swift
//  Constellating
//
//  Stores the user's configured hard drive with security-scoped access.
//

import Foundation

final class DriveSettingsStorage {
    private let driveNameKey = "palimpsest.driveName"
    private let bookmarkKey = "palimpsest.driveBookmark"

    var driveName: String? {
        get {
            UserDefaults.standard.string(forKey: driveNameKey)
        }
        set {
            if let value = newValue, !value.isEmpty {
                UserDefaults.standard.set(value, forKey: driveNameKey)
            } else {
                UserDefaults.standard.removeObject(forKey: driveNameKey)
            }
        }
    }

    // Save the drive with security-scoped bookmark
    func saveDrive(url: URL) throws {
        // Create a security-scoped bookmark
        let bookmarkData = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)

        // Extract drive name from path
        let pathComponents = url.pathComponents
        if let volumeIndex = pathComponents.firstIndex(of: "Volumes"),
           volumeIndex + 1 < pathComponents.count
        {
            driveName = pathComponents[volumeIndex + 1]
        } else {
            driveName = url.lastPathComponent
        }
    }

    // Get the drive URL from bookmark
    func resolveDriveURL() -> URL? {
        guard let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey) else {
            return nil
        }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }

        // If bookmark is stale, it might still work but we should notify
        if isStale {
            print("Warning: Bookmark is stale")
        }

        return url
    }

    func clearDrive() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        driveName = nil
    }
}
