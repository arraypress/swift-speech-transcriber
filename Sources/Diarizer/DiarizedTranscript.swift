//
//  DiarizedTranscript.swift
//  Diarizer
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A speaker turn — who spoke during a time window — from diarization.
public struct SpeakerTurn: Sendable, Equatable {

    /// The 0-based speaker index. `-1` means no speaker was assigned.
    public let speaker: Int

    /// Start time in seconds.
    public let start: Double

    /// End time in seconds.
    public let end: Double

    public init(speaker: Int, start: Double, end: Double) {
        self.speaker = speaker
        self.start = start
        self.end = end
    }
}

/// A transcript segment annotated with the speaker who said it.
public struct DiarizedSegment: Sendable, Equatable {

    /// The 0-based speaker index (`-1` if unknown).
    public let speaker: Int

    /// The recognised text.
    public let text: String

    /// Start time in seconds.
    public let start: Double

    /// End time in seconds.
    public let end: Double

    /// A display label such as `"Speaker 1"` (or `"Unknown"`).
    public var speakerLabel: String {
        speaker >= 0 ? "Speaker \(speaker + 1)" : "Unknown"
    }

    /// The start time formatted as `"M:SS"` or `"H:MM:SS"`.
    public var formattedStart: String { DiarizerTime.clock(start) }

    public init(speaker: Int, text: String, start: Double, end: Double) {
        self.speaker = speaker
        self.text = text
        self.start = start
        self.end = end
    }
}

/// A transcript with speaker labels applied.
///
/// ```swift
/// let diarized = try await Diarizer.diarize(transcript, audioURL: url)
/// print(diarized.speakerCount)        // e.g. 2
/// print(diarized.plainText)           // "Speaker 1: …\nSpeaker 2: …"
/// ```
public struct DiarizedTranscript: Sendable {

    /// The speaker-labelled segments, in chronological order.
    public let segments: [DiarizedSegment]

    /// The number of distinct speakers detected.
    public let speakerCount: Int

    public init(segments: [DiarizedSegment], speakerCount: Int) {
        self.segments = segments
        self.speakerCount = speakerCount
    }

    /// Speaker-prefixed text, merging consecutive segments by the same speaker.
    ///
    /// ```
    /// Speaker 1: Hello, thanks for joining.
    /// Speaker 2: Happy to be here.
    /// ```
    public var plainText: String {
        var lines: [String] = []
        var currentSpeaker: Int?
        var buffer: [String] = []
        func flush() {
            guard let speaker = currentSpeaker, !buffer.isEmpty else { return }
            let label = speaker >= 0 ? "Speaker \(speaker + 1)" : "Unknown"
            lines.append("\(label): \(buffer.joined(separator: " "))")
        }
        for segment in segments {
            if segment.speaker != currentSpeaker {
                flush()
                currentSpeaker = segment.speaker
                buffer = []
            }
            buffer.append(segment.text)
        }
        flush()
        return lines.joined(separator: "\n")
    }

    /// Timestamped, speaker-labelled lines (one per segment).
    ///
    /// ```
    /// [0:00] Speaker 1: Hello everyone
    /// [0:04] Speaker 2: Hi
    /// ```
    public var timestampedText: String {
        segments
            .map { "[\($0.formattedStart)] \($0.speakerLabel): \($0.text)" }
            .joined(separator: "\n")
    }
}

/// Minimal time formatting (the equivalent helper in SpeechTranscriber is internal).
enum DiarizerTime {
    static func clock(_ seconds: Double) -> String {
        let total = Int(max(0, seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }
}
