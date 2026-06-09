//
//  AudioSource.swift
//  SpeechTranscriber
//
//  Created by David Sherlock on 2026.
//

import AVFoundation
import Foundation

/// Fetches a local audio file to transcribe from a remote audio URL or a
/// local/remote video URL.
///
/// All temporary files are written to `FileManager.temporaryDirectory`, which
/// is writable inside the App Sandbox without a security-scoped grant. Callers
/// are responsible for removing the returned file when finished.
enum AudioSource {

    /// Downloads a remote audio file to a temporary location.
    ///
    /// - Parameter url: A remote audio URL.
    /// - Throws: ``TranscriptionError/downloadFailed(_:)`` if the download fails.
    /// - Returns: A local file URL the caller must delete when finished.
    static func download(_ url: URL) async throws -> URL {
        do {
            let (downloadedURL, _) = try await URLSession.shared.download(from: url)

            let rawExtension = url.pathExtension.split(separator: "?").first.map(String.init) ?? ""
            let ext = rawExtension.isEmpty ? "audio" : rawExtension
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("st-\(UUID().uuidString).\(ext)")

            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: downloadedURL, to: destination)
            return destination
        } catch let error as TranscriptionError {
            throw error
        } catch {
            throw TranscriptionError.downloadFailed(error.localizedDescription)
        }
    }

    /// Extracts the audio track of a local or remote video to a temporary `.m4a`.
    ///
    /// Reads the video with `AVURLAsset` (which streams remote progressive
    /// files directly) and exports the audio with `AVAssetExportSession` using
    /// the Apple M4A preset.
    ///
    /// - Parameter url: A local file URL or a remote video URL.
    /// - Throws: ``TranscriptionError/noAudioTrack`` if the video has no audio,
    ///   or ``TranscriptionError/audioExtractionFailed(_:)`` if the export fails.
    /// - Returns: A local `.m4a` file URL the caller must delete when finished.
    static func extractAudio(fromVideo url: URL) async throws -> URL {
        let asset = AVURLAsset(url: url)

        let audioTracks: [AVAssetTrack]
        do {
            audioTracks = try await asset.loadTracks(withMediaType: .audio)
        } catch {
            throw TranscriptionError.audioExtractionFailed(error.localizedDescription)
        }

        guard !audioTracks.isEmpty else {
            throw TranscriptionError.noAudioTrack
        }

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("st-\(UUID().uuidString).m4a")
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
