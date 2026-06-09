//
//  WhisperAudioSource.swift
//  WhisperTranscriber
//
//  Created by David Sherlock on 2026.
//

@preconcurrency import AVFoundation
import Foundation
import SpeechTranscriber

/// Fetches a local audio file to transcribe from a remote audio URL or a
/// local/remote video URL. Mirrors the Apple engine's audio handling so the
/// Whisper engine accepts the same inputs.
enum WhisperAudioSource {

    /// Downloads a remote audio file to a temporary location.
    static func download(_ url: URL) async throws -> URL {
        do {
            let (downloadedURL, _) = try await URLSession.shared.download(from: url)
            let rawExtension = url.pathExtension.split(separator: "?").first.map(String.init) ?? ""
            let ext = rawExtension.isEmpty ? "audio" : rawExtension
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("wk-\(UUID().uuidString).\(ext)")
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: downloadedURL, to: destination)
            return destination
        } catch {
            throw TranscriptionError.downloadFailed(error.localizedDescription)
        }
    }

    /// Extracts the audio track of a local or remote video to a temporary `.m4a`.
    static func extractAudio(fromVideo url: URL) async throws -> URL {
        let asset = AVURLAsset(url: url)

        let audioTracks: [AVAssetTrack]
        do {
            audioTracks = try await asset.loadTracks(withMediaType: .audio)
        } catch {
            throw TranscriptionError.audioExtractionFailed(error.localizedDescription)
        }
        guard !audioTracks.isEmpty else { throw TranscriptionError.noAudioTrack }

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("wk-\(UUID().uuidString).m4a")
        try? FileManager.default.removeItem(at: destination)

        guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw TranscriptionError.audioExtractionFailed("Could not create an export session.")
        }
        do {
            try await export.export(to: destination, as: .m4a)
        } catch {
            throw TranscriptionError.audioExtractionFailed(error.localizedDescription)
        }
        return destination
    }
}
