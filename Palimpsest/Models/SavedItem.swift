//
//  SavedItem.swift
//  Palimpsest
//
//  Model for items saved to the collection with voice recordings.
//

import Foundation

struct SavedItem: Codable, Identifiable {
    let id: UUID
    let sourceTitle: String
    let sourceURL: String
    let audioFilePath: String
    let transcription: String
    let savedAt: Date
    var transferredAt: Date?
    var transferWeek: String?
    var driveName: String?
    var mediaFilePaths: [String]

    var isTransferred: Bool {
        transferredAt != nil
    }

    init(
        id: UUID = UUID(),
        sourceTitle: String,
        sourceURL: String,
        audioFilePath: String,
        transcription: String,
        savedAt: Date = Date(),
        transferredAt: Date? = nil,
        transferWeek: String? = nil,
        driveName: String? = nil,
        mediaFilePaths: [String] = []
    ) {
        self.id = id
        self.sourceTitle = sourceTitle
        self.sourceURL = sourceURL
        self.audioFilePath = audioFilePath
        self.transcription = transcription
        self.savedAt = savedAt
        self.transferredAt = transferredAt
        self.transferWeek = transferWeek
        self.driveName = driveName
        self.mediaFilePaths = mediaFilePaths
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        sourceTitle = try container.decode(String.self, forKey: .sourceTitle)
        sourceURL = try container.decode(String.self, forKey: .sourceURL)
        audioFilePath = try container.decode(String.self, forKey: .audioFilePath)
        transcription = try container.decode(String.self, forKey: .transcription)
        savedAt = try container.decode(Date.self, forKey: .savedAt)
        transferredAt = try container.decodeIfPresent(Date.self, forKey: .transferredAt)
        transferWeek = try container.decodeIfPresent(String.self, forKey: .transferWeek)
        driveName = try container.decodeIfPresent(String.self, forKey: .driveName)
        mediaFilePaths = try container.decodeIfPresent([String].self, forKey: .mediaFilePaths) ?? []
    }
}
