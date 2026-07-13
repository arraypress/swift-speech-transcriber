//
//  ParakeetText.swift
//  ParakeetTranscriber
//
//  Created by David Sherlock on 2026.
//

import Foundation
import SpeechTranscriber
import FluidAudio

/// Builds ``Transcript`` segments from a Parakeet result.
///
/// FluidAudio returns one detokenised `text` string plus per-token timings.
/// We keep the canonical text exactly as produced (no re-detokenisation, which
/// could subtly differ) and split it into sentence segments, assigning each a
/// time range proportional to its length across the spoken span.
///
/// > Note: Timestamps are proportional approximations. Token-timing-accurate
/// > per-segment boundaries are a future enhancement; the text itself is exact.
enum ParakeetText {

    static func segments(
        from timings: [TokenTiming]?,
        fallbackText: String,
        duration: TimeInterval
    ) -> [TranscriptSegment] {
        let full = fallbackText
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !full.isEmpty else { return [] }

        // The spoken span: use real token timings when available, else the
        // whole audio duration.
        let spanStart = timings?.first?.startTime ?? 0
        let spanEnd = max(spanStart, timings?.last?.endTime ?? duration)
        let span = spanEnd - spanStart

        let sentences = splitSentences(full)
        guard sentences.count > 1, span > 0 else {
            return [TranscriptSegment(id: 1, text: full, start: 0, end: duration)]
        }

        // Distribute the span proportionally by sentence character length.
        let totalChars = max(1, sentences.reduce(0) { $0 + $1.count })
        var segments: [TranscriptSegment] = []
        var cursor = 0
        for (index, sentence) in sentences.enumerated() {
            let start = spanStart + span * Double(cursor) / Double(totalChars)
            cursor += sentence.count
            let end = spanStart + span * Double(cursor) / Double(totalChars)
            segments.append(TranscriptSegment(id: index + 1, text: sentence, start: start, end: end))
        }
        return segments
    }

    /// Splits text into sentences, keeping terminal punctuation with each.
    private static func splitSentences(_ text: String) -> [String] {
        var result: [String] = []
        var current = ""
        for char in text {
            current.append(char)
            if ".!?".contains(char) {
                let trimmed = current.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { result.append(trimmed) }
                current = ""
            }
        }
        let tail = current.trimmingCharacters(in: .whitespaces)
        if !tail.isEmpty { result.append(tail) }
        return result
    }
}
