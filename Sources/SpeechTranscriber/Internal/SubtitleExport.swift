//
//  SubtitleExport.swift
//  SpeechTranscriber
//
//  Created by David Sherlock on 2026.
//
//  Transcript segments as subtitle documents. The FORMAT rules — cue
//  numbering, the arrow separator, the millisecond punctuation, what an
//  empty document looks like — live in swift-subtitle-kit, which is the one
//  place in this fleet that decides them. Three libraries used to decide
//  them separately and two of the three rounded milliseconds differently
//  from the third.
//
//  What stays here is the only part that is this library's business:
//  turning a transcript's segments into cues.
//

import Foundation
import SubtitleKit

/// Assembles SubRip and WebVTT documents from timed segments.
enum SubtitleExport {

    /// The segments as subtitle cues.
    static func cues(_ segments: [TranscriptSegment]) -> [SubtitleCue] {
        segments.map { SubtitleCue(start: $0.start, end: $0.end, text: $0.text) }
    }

    /// A SubRip (`.srt`) document: numbered cues, comma-millisecond stamps.
    ///
    /// No trailing newline: this is a string property rather than a file,
    /// and its exact bytes are pinned by a test.
    static func srt(_ segments: [TranscriptSegment]) -> String {
        SubtitleWriter.render(cues(segments), format: .srt, trailingNewline: false)
    }

    /// A WebVTT (`.vtt`) document. No cues is still a valid document — the
    /// bare `WEBVTT` header — not an empty string.
    static func vtt(_ segments: [TranscriptSegment]) -> String {
        let document = SubtitleWriter.render(cues(segments), format: .vtt, trailingNewline: false)
        // The bare header keeps its newline, as this library has always
        // written it.
        return document == "WEBVTT" ? "WEBVTT\n" : document
    }
}
