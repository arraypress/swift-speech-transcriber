//
//  TranscriptionError.swift
//  SpeechTranscriber
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Errors that can occur during on-device speech transcription.
///
/// All errors include a human-readable ``errorDescription`` suitable for
/// display in UI or logging.
///
/// ```swift
/// do {
///     let transcript = try await SpeechTranscriber.transcribe(audioURL: url)
/// } catch TranscriptionError.unavailable {
///     print("On-device transcription requires macOS 26 / iOS 26")
/// } catch TranscriptionError.noAudioTrack {
///     print("That video has no audio")
/// } catch {
///     print(error.localizedDescription)
/// }
/// ```
public enum TranscriptionError: Error, LocalizedError, Equatable, Sendable {

    /// On-device speech transcription is not available on this device or OS.
    ///
    /// Check ``SpeechTranscriber/isAvailable`` before transcribing to handle
    /// this gracefully.
    case unavailable

    /// The requested locale has no available on-device speech model.
    ///
    /// The associated string is the BCP 47 identifier that was requested.
    case localeNotSupported(String)

    /// The speech model for the requested locale failed to download or install.
    ///
    /// The associated string contains a description of the underlying failure.
    case modelInstallationFailed(String)

    /// The provided file URL does not point to an existing file.
    case audioFileNotFound

    /// The audio could not be opened or decoded for reading.
    ///
    /// The associated string contains a description of the underlying failure.
    case audioLoadFailed(String)

    /// The provided video contains no audio track to transcribe.
    case noAudioTrack

    /// A remote audio or video file could not be downloaded.
    ///
    /// The associated string contains a description of the underlying failure.
    case downloadFailed(String)

    /// The audio track could not be extracted from the video.
    ///
    /// The associated string contains a description of the underlying failure.
    case audioExtractionFailed(String)

    /// Recognition failed while processing the audio.
    ///
    /// The associated string contains a description of the underlying failure.
    case transcriptionFailed(String)

    /// The audio was processed successfully but produced no spoken text.
    ///
    /// Typically means the audio was silent or contained no recognisable speech.
    case emptyTranscript

    public var errorDescription: String? {
        switch self {
        case .unavailable:
            return "On-device speech transcription is not available on this device. It requires macOS 26 or iOS 26."
        case .localeNotSupported(let identifier):
            return "No on-device speech model is available for the locale \"\(identifier)\"."
        case .modelInstallationFailed(let message):
            return "Speech model installation failed: \(message)"
        case .audioFileNotFound:
            return "The audio file could not be found."
        case .audioLoadFailed(let message):
            return "The audio could not be loaded: \(message)"
        case .noAudioTrack:
            return "The video contains no audio track."
        case .downloadFailed(let message):
            return "Download failed: \(message)"
        case .audioExtractionFailed(let message):
            return "Audio extraction failed: \(message)"
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        case .emptyTranscript:
            return "The audio produced no recognisable speech."
        }
    }

}
