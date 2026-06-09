//
//  WhisperTranscriber.swift
//  WhisperTranscriber
//
//  Created by David Sherlock on 2026.
//
//  Public API only. WhisperKit (whose `TranscriptionProgress` collides with
//  ours) is imported solely in `WhisperEngine.swift`, so this file can use the
//  shared `Transcript` / `TranscriptionProgress` types unambiguously.

@preconcurrency import AVFoundation
import Foundation
import SpeechTranscriber

/// Transcribe audio and video on-device with OpenAI Whisper, via WhisperKit.
///
/// A drop-in alternative to the Apple ``SpeechTranscriber`` engine: it accepts
/// the same inputs (local audio file, remote audio URL, or local/remote video)
/// and returns the **same** ``Transcript`` type, so subtitle (SRT/VTT) and JSON
/// export, segments, and timing all work identically. Choose it when you want
/// Whisper's accuracy and 100-language coverage; choose the Apple engine for
/// raw speed on macOS 26 / iOS 26.
///
/// Models run entirely on-device (CoreML / Neural Engine) and are downloaded
/// from Hugging Face on first use, then cached.
///
/// ```swift
/// import WhisperTranscriber
///
/// let transcript = try await WhisperTranscriber.transcribe(audioURL: url, model: .largeV3Turbo)
/// print(transcript.plainText)
/// try transcript.srt.write(to: srtURL, atomically: true, encoding: .utf8)
/// ```
public enum WhisperTranscriber {

    /// Transcribes a local audio file or a remote audio URL with Whisper.
    ///
    /// - Parameters:
    ///   - audioURL: A local file URL or a remote audio URL (downloaded first).
    ///   - model: The Whisper model variant. Default ``WhisperModel/auto``.
    ///   - language: An ISO language code (e.g. `"en"`) to force, or `nil` to
    ///     auto-detect (Whisper's default).
    ///   - progress: An optional progress callback.
    /// - Throws: ``TranscriptionError``.
    /// - Returns: A ``Transcript`` of timestamped segments.
    public static func transcribe(
        audioURL: URL,
        model: WhisperModel = .auto,
        language: String? = nil,
        translate: Bool = false,
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
            localURL = try await WhisperAudioSource.download(audioURL)
            temporaryURL = localURL
        }
        defer { if let temporaryURL { try? FileManager.default.removeItem(at: temporaryURL) } }

        return try await WhisperEngine.run(localFile: localURL, model: model, language: language, translate: translate, progress: progress)
    }

    /// Transcribes the audio track of a local or remote video with Whisper.
    ///
    /// - Parameters:
    ///   - videoURL: A local file URL or a remote video URL.
    ///   - model: The Whisper model variant. Default ``WhisperModel/auto``.
    ///   - language: An ISO language code to force, or `nil` to auto-detect.
    ///   - progress: An optional progress callback.
    /// - Throws: ``TranscriptionError`` — in particular ``TranscriptionError/noAudioTrack``.
    /// - Returns: A ``Transcript``.
    public static func transcribe(
        videoURL: URL,
        model: WhisperModel = .auto,
        language: String? = nil,
        translate: Bool = false,
        progress: (@Sendable (TranscriptionProgress) -> Void)? = nil
    ) async throws -> Transcript {

        if videoURL.isFileURL {
            guard FileManager.default.fileExists(atPath: videoURL.path) else {
                throw TranscriptionError.audioFileNotFound
            }
        }
        progress?(TranscriptionProgress(phase: .extractingAudio, fraction: 0))
        let audioURL = try await WhisperAudioSource.extractAudio(fromVideo: videoURL)
        defer { try? FileManager.default.removeItem(at: audioURL) }

        return try await WhisperEngine.run(localFile: audioURL, model: model, language: language, translate: translate, progress: progress)
    }
}
