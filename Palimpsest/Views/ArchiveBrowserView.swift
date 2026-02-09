//
//  ArchiveBrowserView.swift
//  Palimpsest
//
//  Browse archived items from the connected hard drive.
//

import AppKit
import SwiftUI

struct ArchiveBrowserView: View {
    @EnvironmentObject private var hardDriveModeManager: HardDriveModeManager
    @StateObject private var audioPlayer = AudioPlayer()

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "externaldrive.fill")
                                .foregroundColor(.accentColor)
                            Text("Hard Drive Mode")
                                .font(LectorFont.title2)
                        }
                        if let driveName = hardDriveModeManager.connectedDriveName {
                            Text("Browsing: \(driveName)")
                                .font(LectorFont.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Button("Exit") {
                        hardDriveModeManager.exitHardDriveMode()
                    }
                }
                .padding()
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)

                // Archive contents
                if hardDriveModeManager.archiveWeeks.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "folder")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No archived items found")
                            .font(LectorFont.headline)
                        Text("Transfer items from your collection to populate the archive.")
                            .font(LectorFont.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                } else {
                    ForEach(hardDriveModeManager.archiveWeeks) { week in
                        ArchiveWeekSection(
                            week: week,
                            audioPlayer: audioPlayer,
                            dateFormatter: dateFormatter
                        )
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Archive")
    }
}

struct ArchiveWeekSection: View {
    let week: ArchiveWeek
    @ObservedObject var audioPlayer: AudioPlayer
    let dateFormatter: DateFormatter
    @State private var isExpanded: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }, label: {
                HStack {
                    Text(week.name)
                        .font(LectorFont.headline)
                        .foregroundColor(.primary)
                    Text("(\(week.items.count) items)")
                        .font(LectorFont.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            })
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(week.items) { item in
                        ArchivedItemRow(
                            item: item,
                            audioPlayer: audioPlayer,
                            dateFormatter: dateFormatter
                        )
                    }
                }
                .padding(.leading, 16)
            }
        }
    }
}

struct ArchivedItemRow: View {
    let item: ArchivedItem
    @ObservedObject var audioPlayer: AudioPlayer
    let dateFormatter: DateFormatter
    @State private var showMedia: Bool = false

    private var isPlaying: Bool {
        audioPlayer.playingURL == item.audioURL?.path
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with title and URL (full access in archive mode)
            VStack(alignment: .leading, spacing: 4) {
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
                                .foregroundColor(.accentColor)
                                .lineLimit(2)
                            Image(systemName: "arrow.up.right")
                                .font(LectorFont.caption2)
                                .foregroundColor(.accentColor)
                        }
                    })
                    .buttonStyle(PlainButtonStyle())
                }
            }

            // Audio playback
            if let audioURL = item.audioURL {
                HStack {
                    Button(action: {
                        audioPlayer.togglePlayback(url: audioURL, path: audioURL.path)
                    }, label: {
                        HStack(spacing: 8) {
                            Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                                .foregroundColor(.accentColor)
                            Text(isPlaying ? "Stop" : "Play Recording")
                                .font(LectorFont.subheadline)
                                .foregroundColor(.accentColor)
                        }
                    })
                    .buttonStyle(PlainButtonStyle())

                    Spacer()
                }
            }

            // Transcription
            if !item.transcription.isEmpty {
                Text(item.transcription)
                    .font(LectorFont.body)
                    .foregroundColor(.secondary)
            }

            // Media attachments
            if !item.mediaURLs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Button(action: { showMedia.toggle() }, label: {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                            Text("\(item.mediaURLs.count) attachment\(item.mediaURLs.count == 1 ? "" : "s")")
                                .font(LectorFont.caption)
                            Image(systemName: showMedia ? "chevron.up" : "chevron.down")
                                .font(LectorFont.caption)
                        }
                        .foregroundColor(.secondary)
                    })
                    .buttonStyle(PlainButtonStyle())

                    if showMedia {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(item.mediaURLs, id: \.path) { mediaURL in
                                    MediaThumbnail(url: mediaURL)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct MediaThumbnail: View {
    let url: URL

    var body: some View {
        Group {
            if let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 80)
                    .clipped()
                    .cornerRadius(4)
                    .onTapGesture {
                        NSWorkspace.shared.open(url)
                    }
            } else {
                // Video or unknown type
                ZStack {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 120, height: 80)
                        .cornerRadius(4)
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                }
                .onTapGesture {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}
