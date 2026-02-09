//
//  RecordingPanelView.swift
//  Palimpsest
//
//  Panel shown when saving a source. Requires voice recording before save.
//  Transcription (Whisper) will be added later.
//

import SwiftUI

struct RecordingPanelView: View {
    let sourceTitle: String
    let sourceURL: String
    let onSave: (SavedItem) -> Void
    let onCancel: () -> Void

    @StateObject private var recordingService = AudioRecordingService()
    @State private var audioFilePath: String = ""
    @State private var isStopping: Bool = false
    @State private var errorMessage: String?
    @State private var permissionRequested: Bool = false

    private var canSave: Bool {
        !audioFilePath.isEmpty && !recordingService.isRecording
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(sourceTitle)
                    .font(LectorFont.headline)
                    .lineLimit(3)
                Text(sourceURL)
                    .font(LectorFont.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let error = errorMessage {
                Text(error)
                    .font(LectorFont.caption)
                    .foregroundColor(.red)
            }

            HStack {
                Button(action: toggleRecording) {
                    ZStack {
                        Circle()
                            .fill(recordingService.isRecording ? Color.red
                                .opacity(0.3) : Color(NSColor.controlBackgroundColor)
                            )
                            .frame(width: 64, height: 64)
                        if recordingService.isRecording {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 48, height: 48)
                                .scaleEffect(recordingService.isRecording ? 1.1 : 1.0)
                                .animation(
                                    .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                                    value: recordingService.isRecording
                                )
                        }
                        Image(systemName: recordingService.isRecording ? "stop.fill" : "mic.fill")
                            .font(LectorFont.custom(LectorFont.regular, size: 24))
                            .foregroundColor(recordingService.isRecording ? .white : .primary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isStopping)

                VStack(alignment: .leading, spacing: 4) {
                    if recordingService.isRecording {
                        Text("Recording…")
                            .font(LectorFont.subheadline)
                            .foregroundColor(.secondary)
                    } else if isStopping {
                        Text("Stopping…")
                            .font(LectorFont.subheadline)
                            .foregroundColor(.secondary)
                    } else if !audioFilePath.isEmpty {
                        Text("Recorded. Tap mic to re-record or Save.")
                            .font(LectorFont.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Record your reaction to save")
                            .font(LectorFont.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }

            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    saveAndDismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
        }
        .padding(24)
        .frame(width: 360)
        .task {
            await requestPermissionsIfNeeded()
        }
    }

    private func requestPermissionsIfNeeded() async {
        guard !permissionRequested else { return }
        permissionRequested = true
        do {
            _ = try await recordingService.requestPermissions()
        } catch {
            errorMessage = "Microphone permission denied."
        }
    }

    private func toggleRecording() {
        if recordingService.isRecording {
            Task {
                await stopRecording()
            }
        } else {
            errorMessage = nil
            audioFilePath = ""
            do {
                try recordingService.startRecording()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func stopRecording() async {
        isStopping = true
        errorMessage = nil
        do {
            let url = try await recordingService.stopRecording()
            audioFilePath = url.path
        } catch {
            errorMessage = error.localizedDescription
        }
        isStopping = false
    }

    private func saveAndDismiss() {
        guard canSave else { return }
        let item = SavedItem(
            sourceTitle: sourceTitle,
            sourceURL: sourceURL,
            audioFilePath: audioFilePath,
            transcription: "",
            savedAt: Date()
        )
        onSave(item)
    }
}
