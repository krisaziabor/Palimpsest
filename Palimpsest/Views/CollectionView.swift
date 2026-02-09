//
//  CollectionView.swift
//  Palimpsest
//
//  Lists saved items with audio playback and source metadata.
//

import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

struct CollectionView: View {
    @EnvironmentObject private var collectionManager: CollectionManager
    @EnvironmentObject private var transferManager: TransferManager
    @StateObject private var collectionAudioPlayer = AudioPlayer()
    @State private var isTransferring = false
    @State private var transferError: String?
    @State private var transferSuccess = false

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                NextSundayBanner()

                if !collectionManager.untransferredItems.isEmpty {
                    HStack {
                        Button(action: performTransfer) {
                            if isTransferring {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Label("Transfer to Drive", systemImage: "externaldrive")
                            }
                        }
                        .disabled(isTransferring || collectionManager.untransferredItems.isEmpty)

                        if let err = transferError {
                            Text(err)
                                .font(LectorFont.caption)
                                .foregroundColor(.red)
                        }
                        if transferSuccess {
                            Text("Transfer complete.")
                                .font(LectorFont.caption)
                                .foregroundColor(.green)
                        }
                    }
                }

                if collectionManager.allItems.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bookmark.slash")
                            .font(LectorFont.custom(LectorFont.regular, size: 48))
                            .foregroundColor(.secondary)
                        Text("No saved items yet")
                            .font(LectorFont.headline)
                        Text("Save websites from search to build your collection")
                            .font(LectorFont.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(collectionManager.allItems) { item in
                            SavedItemRow(item: item, dateFormatter: dateFormatter, audioPlayer: collectionAudioPlayer)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Collection")
    }

    private func performTransfer() {
        transferError = nil
        transferSuccess = false
        isTransferring = true

        Task {
            do {
                try await transferManager.performTransfer()
                transferSuccess = true
            } catch TransferError.driveNotFound {
                transferError = "Drive not found. Check the name in Settings."
            } catch TransferError.palimpsestFolderNotFound {
                transferError = "Palimpsest folder not found on drive."
            } catch let TransferError.transferFailed(msg) {
                transferError = msg
            } catch {
                transferError = error.localizedDescription
            }
            isTransferring = false
        }
    }
}

/// Extracted view to isolate .onDrop from parent layout; reduces layout recursion.
private struct MediaDropZone: View {
    let onDrop: ([NSItemProvider]) -> Bool
    let addMediaAction: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: addMediaAction) {
                Label("Add Media", systemImage: "plus.rectangle.on.rectangle")
                    .font(LectorFont.caption)
            }
            .buttonStyle(PlainButtonStyle())

            Text("or drop screenshots/videos")
                .font(LectorFont.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .cornerRadius(6)
        .onDrop(of: [.image, .movie, .fileURL], isTargeted: nil, perform: onDrop)
    }
}

struct NextSundayBanner: View {
    var body: some View {
        let (nextDate, daysUntil) = NextSundayCalculator.nextSunday()
        let dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter
        }()
        HStack {
            Image(systemName: "calendar")
                .foregroundColor(.secondary)
            Text("Next session: \(dateFormatter.string(from: nextDate)) (\(daysUntil) days)")
                .font(LectorFont.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct SavedItemRow: View {
    let item: SavedItem
    let dateFormatter: DateFormatter
    @ObservedObject var audioPlayer: AudioPlayer
    @EnvironmentObject private var collectionManager: CollectionManager

    private var isThisItemPlaying: Bool {
        audioPlayer.playingURL == item.audioFilePath
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Button(action: {
                    audioPlayer.togglePlayback(
                        url: URL(fileURLWithPath: item.audioFilePath),
                        path: item.audioFilePath
                    )
                }, label: {
                    Image(systemName: isThisItemPlaying ? "stop.fill" : "play.fill")
                        .font(LectorFont.custom(LectorFont.regular, size: 20))
                        .foregroundColor(.accentColor)
                        .frame(width: 44, height: 44)
                })
                .buttonStyle(PlainButtonStyle())

                VStack(alignment: .leading, spacing: 4) {
                    if !item.isTransferred {
                        HStack {
                            Text(item.sourceTitle)
                                .font(LectorFont.headline)
                                .lineLimit(3)
                            Spacer()
                            Text(item.savedAt, formatter: dateFormatter)
                                .font(LectorFont.caption)
                                .foregroundColor(.secondary)
                        }
                        if let url = URL(string: item.sourceURL) {
                            Button(action: { NSWorkspace.shared.open(url) }, label: {
                                HStack(spacing: 4) {
                                    Text(item.sourceURL)
                                        .font(LectorFont.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(3)
                                    Image(systemName: "arrow.up.right")
                                        .font(LectorFont.caption2)
                                        .foregroundColor(.secondary)
                                }
                            })
                            .buttonStyle(PlainButtonStyle())
                        }
                    } else {
                        HStack {
                            Image(systemName: "externaldrive.fill")
                                .foregroundColor(.secondary)
                            Text("\(item.driveName ?? "Unknown drive") · \(item.transferWeek ?? "Unknown week")")
                                .font(LectorFont.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(item.savedAt, formatter: dateFormatter)
                                .font(LectorFont.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if !item.transcription.isEmpty {
                        Text(item.transcription)
                            .font(LectorFont.body)
                            .foregroundColor(.secondary)
                            .lineLimit(6)
                    }

                    if !item.isTransferred {
                        mediaSection
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    @ViewBuilder
    private var mediaSection: some View {
        HStack {
            if !item.mediaFilePaths.isEmpty {
                Label(
                    "\(item.mediaFilePaths.count) attachment\(item.mediaFilePaths.count == 1 ? "" : "s")",
                    systemImage: "photo.on.rectangle"
                )
                .font(LectorFont.caption)
                .foregroundColor(.secondary)
            }
            Spacer()
            mediaDropZone
        }
    }

    private var mediaDropZone: some View {
        MediaDropZone(
            onDrop: handleDroppedProviders,
            addMediaAction: addMedia
        )
    }

    private func addMedia() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image, .movie]
        if panel.runModal() == .OK {
            for url in panel.urls {
                collectionManager.addMediaFromURL(to: item.id, sourceURL: url)
            }
        }
    }

    private func handleDroppedProviders(_ providers: [NSItemProvider]) -> Bool {
        let itemId = item.id
        for provider in providers {
            let types: [UTType] = [.image, .movie, .fileURL]
            for type in types where provider.hasItemConformingToTypeIdentifier(type.identifier) {
                _ = provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, _ in
                    guard let url else { return }
                    if let destPath = CollectionManager.copyMediaToStorage(itemId: itemId, sourceURL: url) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            collectionManager.addMedia(to: itemId, filePath: destPath)
                        }
                    }
                }
                break
            }
        }
        return true
    }
}

final class AudioPlayer: NSObject, ObservableObject {
    @Published var playingURL: String?
    private var player: AVAudioPlayer?

    func togglePlayback(url: URL, path: String) {
        if playingURL == path {
            player?.stop()
            player = nil
            playingURL = nil
            return
        }
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.play()
            playingURL = path
        } catch {
            // Silently fail if audio unavailable
        }
    }
}

extension AudioPlayer: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        playingURL = nil
    }
}
