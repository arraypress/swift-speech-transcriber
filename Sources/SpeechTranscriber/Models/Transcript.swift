//
//  Transcript.swift
//  SpeechTranscriber
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// The result of transcribing audio, containing timed segments and convenient
/// derived and exported representations.
///
/// ```swift
/// let transcript = try await SpeechTranscriber.transcribe(audioURL: url)
///
/// print(transcript.plainText)        // Continuous text
/// print(transcript.timestampedText)  // "[0:00] Hello everyone"
/// print(transcript.formattedDuration) // "3:32"
/// print(transcript.wordCount)         // 612
///
/// // Subtitle + JSON exports
/// let srt = transcript.srt
/// let vtt = transcript.vtt
/// let json = try transcript.jsonString()
/// ```
public struct Transcript: Sendable {

    /// The transcript segments, in chronological order.
    public let segments: [TranscriptSegment]

    /// The total audio duration in seconds.
    public let audioDuration: TimeInterval

    /// The wall-clock time spent transcribing, in seconds.
    ///
    /// Combined with ``audioDuration`` this gives ``speedFactor``.
    public let transcriptionTime: TimeInterval

    /// The BCP 47 identifier of the locale used (e.g., `"en-US"`).
    public let localeIdentifier: String

    /// Creates a transcript.
    ///
    /// - Parameters:
    ///   - segments: The timed segments in chronological order.
    ///   - audioDuration: The total audio duration in seconds.
    ///   - transcriptionTime: The wall-clock transcription time in seconds.
    ///   - localeIdentifier: The BCP 47 locale identifier used.
    public init(
        segments: [TranscriptSegment],
        audioDuration: TimeInterval,
        transcriptionTime: TimeInterval,
        localeIdentifier: String
    ) {
        self.segments = segments
        self.audioDuration = audioDuration
        self.transcriptionTime = transcriptionTime
        self.localeIdentifier = localeIdentifier
    }

    // MARK: - Derived Text

    /// All segment text joined into a single string, separated by spaces.
    public var plainText: String {
        segments.map(\.text).joined(separator: " ")
    }

    /// The full transcript with timestamps, one segment per line.
    ///
    /// ```
    /// [0:00] Hello everyone
    /// [0:02] Welcome to the show
    /// ```
    public var timestampedText: String {
        segments.map { "[\($0.formattedStart)] \($0.text)" }.joined(separator: "\n")
    }

    /// The number of segments in the transcript.
    public var count: Int {
        segments.count
    }

    /// Whether the transcript has no segments.
    public var isEmpty: Bool {
        segments.isEmpty
    }

    /// The total number of words across all segments.
    public var wordCount: Int {
        plainText.split { $0 == " " || $0.isNewline }.count
    }

    // MARK: - Statistics

    /// The audio duration formatted as `"M:SS"` or `"H:MM:SS"`.
    public var formattedDuration: String {
        TimeCode.clock(audioDuration)
    }

    /// Transcription speed relative to real time (`audioDuration / transcriptionTime`).
    ///
    /// A value of `30` means the audio was transcribed at 30× real time.
    /// Returns `0` when ``transcriptionTime`` is zero.
    public var speedFactor: Double {
        transcriptionTime > 0 ? audioDuration / transcriptionTime : 0
    }

    // MARK: - Subtitle Export

    /// The transcript as a SubRip (`.srt`) subtitle document.
    ///
    /// ```
    /// 1
    /// 00:00:00,000 --> 00:00:02,500
    /// Hello everyone
    ///
    /// 2
    /// 00:00:02,500 --> 00:00:05,000
    /// Welcome to the show
    /// ```
    public var srt: String {
        SubtitleExport.srt(segments)
    }

    /// The transcript as a WebVTT (`.vtt`) subtitle document.
    ///
    /// ```
    /// WEBVTT
    ///
    /// 00:00:00.000 --> 00:00:02.500
    /// Hello everyone
    /// ```
    public var vtt: String {
        SubtitleExport.vtt(segments)
    }

    // MARK: - JSON Export

    /// A compact, JSON-friendly representation of the transcript.
    ///
    /// Designed for passing to LLMs, APIs, or saving to disk. Keys use
    /// `snake_case` formatting.
    struct JSONSummary: Codable, Sendable {

        /// The BCP 47 locale identifier used.
        let locale: String

        /// Formatted audio duration (e.g., "3:32").
        let duration: String

        /// The number of segments.
        let segmentCount: Int

        /// The total word count.
        let wordCount: Int

        /// All segment text joined with spaces.
        let plainText: String

        /// The timed segments.
        let segments: [Entry]

        /// A single transcript segment.
        struct Entry: Codable, Sendable {
            let id: Int
            let start: Double
            let end: Double
            let text: String
        }
    }

    /// Encodes the transcript as JSON `Data`.
    ///
    /// ```swift
    /// let data = try transcript.jsonData()
    /// ```
    ///
    /// - Parameter prettyPrinted: Whether to format with indentation. Default `true`.
    /// - Returns: UTF-8 encoded JSON data with `snake_case` keys.
    /// - Throws: `EncodingError` if encoding fails.
    public func jsonData(prettyPrinted: Bool = true) throws -> Data {
        let summary = JSONSummary(
            locale: localeIdentifier,
            duration: formattedDuration,
            segmentCount: count,
            wordCount: wordCount,
            plainText: plainText,
            segments: segments.map { segment in
                JSONSummary.Entry(
                    id: segment.id,
                    start: segment.start,
                    end: segment.end,
                    text: segment.text
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        return try encoder.encode(summary)
    }

    /// Encodes the transcript as a JSON string.
    ///
    /// - Parameter prettyPrinted: Whether to format with indentation. Default `true`.
    /// - Returns: A JSON string with `snake_case` keys.
    /// - Throws: `EncodingError` if encoding fails.
    public func jsonString(prettyPrinted: Bool = true) throws -> String {
        let data = try jsonData(prettyPrinted: prettyPrinted)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

}
