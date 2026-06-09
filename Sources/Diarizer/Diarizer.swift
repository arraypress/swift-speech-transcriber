//
//  Diarizer.swift
//  Diarizer
//
//  Created by David Sherlock on 2026.
//

import Foundation
import SpeakerKit
import SpeechTranscriber

/// On-device speaker diarization ("who spoke when") via SpeakerKit (pyannote).
///
/// Pair it with either transcription engine to turn a flat ``Transcript`` into a
/// speaker-labelled ``DiarizedTranscript`` — the differentiator for interviews
/// and podcasts. Runs fully on-device; the pyannote models (~10 MB) download
/// from Hugging Face on first use, then cache.
///
/// ```swift
/// import SpeechTranscriber
/// import Diarizer
///
/// let transcript = try await SpeechTranscriber.transcribe(audioURL: url)
/// let diarized   = try await Diarizer.diarize(transcript, audioURL: url)
///
/// print(diarized.speakerCount)   // 2
/// print(diarized.plainText)      // "Speaker 1: …\nSpeaker 2: …"
/// ```
public enum Diarizer {

    /// Diarizes an audio file into raw speaker turns ("who spoke when").
    ///
    /// - Parameters:
    ///   - audioURL: A local audio file URL.
    ///   - progress: Optional model-download progress (0–1).
    /// - Throws: ``DiarizationError``.
    /// - Returns: Speaker turns in chronological order.
    public static func diarize(
        audioURL: URL,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> [SpeakerTurn] {

        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw DiarizationError.audioFileNotFound
        }

        let samples = try DiarizerAudioLoader.samples(from: audioURL)

        let speakerKit: SpeakerKit
        do {
            speakerKit = try await SpeakerKit()
        } catch {
            throw DiarizationError.modelLoadFailed(error.localizedDescription)
        }
        _ = progress // model-download progress is reported by SpeakerKit internally; reserved here.

        let result: DiarizationResult
        do {
            result = try await speakerKit.diarize(audioArray: samples)
        } catch {
            throw DiarizationError.diarizationFailed(error.localizedDescription)
        }

        return result.segments.map { segment in
            SpeakerTurn(
                speaker: segment.speaker.speakerId ?? -1,
                start: Double(segment.startTime),
                end: Double(segment.endTime)
            )
        }
    }

    /// Applies speaker labels to an existing ``Transcript``.
    ///
    /// Runs diarization on the same audio, then assigns each transcript segment
    /// the speaker whose turn overlaps it most.
    ///
    /// - Parameters:
    ///   - transcript: A transcript produced by either engine.
    ///   - audioURL: The audio the transcript came from.
    ///   - progress: Optional model-download progress (0–1).
    /// - Throws: ``DiarizationError``.
    /// - Returns: A ``DiarizedTranscript`` with per-segment speakers.
    public static func diarize(
        _ transcript: Transcript,
        audioURL: URL,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> DiarizedTranscript {

        let turns = try await diarize(audioURL: audioURL, progress: progress)

        let labelled = transcript.segments.map { segment in
            DiarizedSegment(
                speaker: bestSpeaker(start: segment.start, end: segment.end, turns: turns),
                text: segment.text,
                start: segment.start,
                end: segment.end
            )
        }
        let speakerCount = Set(turns.map(\.speaker).filter { $0 >= 0 }).count
        return DiarizedTranscript(segments: labelled, speakerCount: speakerCount)
    }

    /// Picks the speaker turn with the greatest temporal overlap of `[start, end]`.
    static func bestSpeaker(start: Double, end: Double, turns: [SpeakerTurn]) -> Int {
        var best = -1
        var bestOverlap = 0.0
        for turn in turns {
            let overlap = min(end, turn.end) - max(start, turn.start)
            if overlap > bestOverlap {
                bestOverlap = overlap
                best = turn.speaker
            }
        }
        return best
    }
}

/// Errors that can occur during diarization.
public enum DiarizationError: Error, LocalizedError, Equatable, Sendable {

    /// The provided file URL does not point to an existing file.
    case audioFileNotFound

    /// The audio could not be loaded or resampled.
    case audioLoadFailed(String)

    /// The SpeakerKit models failed to load or download.
    case modelLoadFailed(String)

    /// Diarization failed while processing the audio.
    case diarizationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .audioFileNotFound:
            return "The audio file could not be found."
        case .audioLoadFailed(let message):
            return "The audio could not be loaded: \(message)"
        case .modelLoadFailed(let message):
            return "Speaker models failed to load: \(message)"
        case .diarizationFailed(let message):
            return "Diarization failed: \(message)"
        }
    }
}
