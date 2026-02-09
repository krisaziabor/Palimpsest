//
//  AudioRecordingService.swift
//  Palimpsest
//
//  Handles voice recording for the save gate. Transcription will be added via Whisper.
//

import AVFoundation
import Foundation

enum AudioRecordingError: Error {
    case permissionDenied
    case permissionRestricted
    case notDetermined
    case recorderSetupFailed
}

@MainActor
final class AudioRecordingService: NSObject, ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?

    override init() {
        super.init()
    }

    /// Request microphone permission. Returns true if authorized, throws if denied/restricted.
    func requestPermissions() async throws -> Bool {
        let granted = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
        guard granted else { throw AudioRecordingError.permissionDenied }
        return true
    }

    /// Start recording. Call requestPermissions() first.
    func startRecording() throws {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsDir = documentsPath.appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true)
        let fileName = "recording_\(UUID().uuidString).m4a"
        recordingURL = recordingsDir.appendingPathComponent(fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        audioRecorder = try AVAudioRecorder(url: recordingURL!, settings: settings)
        audioRecorder?.record()
    }

    /// Stop recording and return the audio URL. No transcription (Whisper coming later).
    func stopRecording() async throws -> URL {
        guard let recorder = audioRecorder, let url = recordingURL else {
            throw AudioRecordingError.recorderSetupFailed
        }
        recorder.stop()
        audioRecorder = nil
        recordingURL = nil
        return url
    }

    var isRecording: Bool {
        audioRecorder?.isRecording ?? false
    }
}
