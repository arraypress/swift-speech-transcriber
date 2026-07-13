//
//  ParakeetTranscriber.swift
//  ParakeetTranscriber
//
//  Created by David Sherlock on 2026.
//
//  Public API only. FluidAudio is imported solely in `ParakeetEngine.swift`,
//  so this file uses the shared `Transcript` / `TranscriptionProgress` types
//  unambiguously.
//

@preconcurrency import AVFoundation
import Foundation
import SpeechTranscriber

/// Transcribe audio and video on-device with NVIDIA Parakeet, via FluidAudio.
///
/// A drop-in alternative to the Apple ``SpeechTranscriber`` and
/// ``WhisperTranscriber`` engines: it accepts the same inputs (local audio
/// file, remote audio URL, or local/remote video) and returns the **same**
/// ``Transcript`` type, so subtitle (SRT/VTT) and JSON export, segments, and
/// timing all work identically.
///
/// Parakeet runs entirely on-device as CoreML on the Apple Neural Engine —
/// fast and power-efficient, which makes it a strong default for real-time
/// dictation. Models are downloaded from Hugging Face on first use, then cached.
///
/// ```swift
/// import ParakeetTranscriber
///
/// let transcript = try await ParakeetTranscriber.transcribe(audioURL: url, model: .englishV2)
/// print(transcript.plainText)
/// ```
public enum ParakeetTranscriber {

    /// Transcribes a local audio file or a remote audio URL with Parakeet.
    ///
    /// - Parameters:
    ///   - audioURL: A local file URL or a remote audio URL (downloaded first).
    ///   - model: The Parakeet model variant. Default ``ParakeetModel/auto``.
    ///   - language: An ISO language code (e.g. `"en"`, `"es"`) to force, or
    ///     `nil` to auto-detect. Only meaningful for the multilingual ``ParakeetModel/multilingualV3``.
    ///   - progress: An optional progress callback.
    /// - Throws: ``TranscriptionError``.
    /// - Returns: A ``Transcript`` of timestamped segments.
    public static func transcribe(
        audioURL: URL,
        model: ParakeetModel = .auto,
        language: String? = nil,
        progress: (@Sendable (TranscriptionProgress) -> Void)? = nil
    ) async throws -> Transcript {

        let localURL: URL
        let temporaryURL: URL?
        if audioURL.isFileURL {
            guard FileManager.default.fileExists(atPath: audioURL.path) else {
                throw TranscriptionError.audioFileNotFound
            }
            localURL = audioURL
            temporaryURL = nil
        } else {
            progress?(TranscriptionProgress(phase: .downloading, fraction: 0))
            localURL = try await ParakeetAudioSource.download(audioURL)
            temporaryURL = localURL
        }
        defer { if let temporaryURL { try? FileManager.default.removeItem(at: temporaryURL) } }

        return try await ParakeetEngine.run(localFile: localURL, model: model, language: language, progress: progress)
    }

    /// Transcribes the audio track of a local or remote video with Parakeet.
    ///
    /// - Parameters:
    ///   - videoURL: A local file URL or a remote video URL.
    ///   - model: The Parakeet model variant. Default ``ParakeetModel/auto``.
    ///   - language: An ISO language code to force, or `nil` to auto-detect.
    ///   - progress: An optional progress callback.
    /// - Throws: ``TranscriptionError`` — in particular ``TranscriptionError/noAudioTrack``.
    /// - Returns: A ``Transcript``.
    public static func transcribe(
        videoURL: URL,
        model: ParakeetModel = .auto,
        language: String? = nil,
        progress: (@Sendable (TranscriptionProgress) -> Void)? = nil
    ) async throws -> Transcript {

        if videoURL.isFileURL {
            guard FileManager.default.fileExists(atPath: videoURL.path) else {
                throw TranscriptionError.audioFileNotFound
            }
        }
        progress?(TranscriptionProgress(phase: .extractingAudio, fraction: 0))
        let audioURL = try await ParakeetAudioSource.extractAudio(fromVideo: videoURL)
        defer { try? FileManager.default.removeItem(at: audioURL) }

        return try await ParakeetEngine.run(localFile: audioURL, model: model, language: language, progress: progress)
    }
}
