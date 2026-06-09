//
//  TranscriptionOptions.swift
//  SpeechTranscriber
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Configuration options for on-device speech transcription.
///
/// All options have sensible defaults — you can transcribe with no
/// configuration at all:
///
/// ```swift
/// let transcript = try await SpeechTranscriber.transcribe(audioURL: url)
/// ```
///
/// Or customise the language and how text is split into segments:
///
/// ```swift
/// let options = TranscriptionOptions(
///     locale: Locale(identifier: "de-DE"),
///     segmentation: .sentence
/// )
/// let transcript = try await SpeechTranscriber.transcribe(audioURL: url, options: options)
/// ```
public struct TranscriptionOptions: Sendable {

    // MARK: - Language

    /// The locale to transcribe in.
    ///
    /// Determines which on-device speech model is used. The first time a
    /// locale is requested its model is downloaded automatically; subsequent
    /// runs are fully offline. If the locale has no available model,
    /// transcription throws ``TranscriptionError/localeNotSupported(_:)``.
    ///
    /// Default is `en-US`.
    public var locale: Locale

    // MARK: - Segmentation

    /// How recognised text is split into ``TranscriptSegment`` values.
    ///
    /// Sentence segmentation produces natural, readable transcript lines and
    /// is the right default for subtitles and documents. Word segmentation
    /// produces one segment per word, useful for karaoke-style highlighting
    /// or fine-grained timing.
    ///
    /// Default is ``Segmentation/sentence``.
    public var segmentation: Segmentation

    // MARK: - Initialisation

    /// Creates transcription options with the specified parameters.
    ///
    /// - Parameters:
    ///   - locale: The transcription locale. Default `en-US`.
    ///   - segmentation: How to split text into segments. Default `.sentence`.
    public init(
        locale: Locale = Locale(identifier: "en-US"),
        segmentation: Segmentation = .sentence
    ) {
        self.locale = locale
        self.segmentation = segmentation
    }

}

// MARK: - Segmentation

/// The strategy for splitting recognised text into ``TranscriptSegment`` values.
///
/// ```swift
/// // Natural sentence-per-line segments (default)
/// let options = TranscriptionOptions(segmentation: .sentence)
///
/// // One segment per word
/// let options = TranscriptionOptions(segmentation: .word)
/// ```
public enum Segmentation: Sendable {

    /// Split text into sentences.
    ///
    /// Produces readable, subtitle-friendly lines. This is the default.
    case sentence

    /// Split text into individual words.
    ///
    /// Produces one segment per word with tight timing, useful for word-level
    /// highlighting.
    case word

}
