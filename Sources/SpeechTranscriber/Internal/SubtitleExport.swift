//
//  SubtitleExport.swift
//  SpeechTranscriber
//
//  Created by David Sherlock on 2026.
//
//  Subtitle documents assembled from segments, as pure functions. The cue
//  numbering, the arrow separators and the empty-document edge are rules,
//  and rules live where a test can pin them without building a transcript.
//

import Foundation

/// Assembles SubRip and WebVTT documents from timed segments.
enum SubtitleExport {

    /// A SubRip (`.srt`) document: numbered cues, comma-millisecond stamps.
    static func srt(_ segments: [TranscriptSegment]) -> String {
        segments.enumerated().map { index, segment in
            """
            \(index + 1)
            \(TimeCode.srt(segment.start)) --> \(TimeCode.srt(segment.end))
            \(segment.text)
            """
        }.joined(separator: "\n\n")
    }

    /// A WebVTT (`.vtt`) document. No cues is still a valid document — the
    /// bare `WEBVTT` header — not an empty string.
    static func vtt(_ segments: [TranscriptSegment]) -> String {
        let cues = segments.map { segment in
            """
            \(TimeCode.vtt(segment.start)) --> \(TimeCode.vtt(segment.end))
            \(segment.text)
            """
        }.joined(separator: "\n\n")

        return cues.isEmpty ? "WEBVTT\n" : "WEBVTT\n\n\(cues)"
    }
}
