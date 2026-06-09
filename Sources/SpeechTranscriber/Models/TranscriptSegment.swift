//
//  TranscriptSegment.swift
//  SpeechTranscriber
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A single timed segment of a transcript.
///
/// Each segment represents a sentence (or word, depending on
/// ``Segmentation``) recognised from the audio, with the time window during
/// which it was spoken.
///
/// ```swift
/// for segment in transcript.segments {
///     print("[\(segment.formattedStart)] \(segment.text)")
/// }
/// ```
public struct TranscriptSegment: Codable, Equatable, Identifiable, Sendable {

    /// A stable, 1-based identifier for this segment within its transcript.
    public let id: Int

    /// The recognised text of this segment.
    public let text: String

    /// The start time in seconds from the beginning of the audio.
    public let start: Double

    /// The end time in seconds from the beginning of the audio.
    public let end: Double

    /// The spoken duration of this segment in seconds (`end - start`).
    public var duration: Double {
        max(0, end - start)
    }

    /// The start time formatted as `"M:SS"` or `"H:MM:SS"` for longer audio.
    ///
    /// ```swift
    /// // "0:00", "1:23", "1:05:30"
    /// print(segment.formattedStart)
    /// ```
    public var formattedStart: String {
        TimeCode.clock(start)
    }

    /// The end time formatted as `"M:SS"` or `"H:MM:SS"` for longer audio.
    public var formattedEnd: String {
        TimeCode.clock(end)
    }

    /// Creates a transcript segment.
    ///
    /// - Parameters:
    ///   - id: A 1-based identifier within the transcript.
    ///   - text: The recognised text.
    ///   - start: The start time in seconds.
    ///   - end: The end time in seconds.
    public init(id: Int, text: String, start: Double, end: Double) {
        self.id = id
        self.text = text
        self.start = start
        self.end = end
    }
}
