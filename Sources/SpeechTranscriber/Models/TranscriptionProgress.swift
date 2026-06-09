//
//  TranscriptionProgress.swift
//  SpeechTranscriber
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Progress information reported during transcription.
///
/// Sent via the progress callback in
/// ``SpeechTranscriber/transcribe(audioURL:options:progress:)`` and
/// ``SpeechTranscriber/transcribe(videoURL:options:progress:)``.
///
/// ```swift
/// let transcript = try await SpeechTranscriber.transcribe(audioURL: url) { progress in
///     print(progress.statusText)              // "Transcribing: 42%"
///     progressBar.progress = progress.fraction // 0.0–1.0
/// }
/// ```
public struct TranscriptionProgress: Sendable {

    /// The current processing phase.
    public enum Phase: String, Sendable {
        /// Downloading a remote audio or video file.
        case downloading = "Downloading"
        /// Extracting the audio track from a video.
        case extractingAudio = "Extracting audio"
        /// Downloading and installing the on-device speech model.
        case installingModel = "Installing model"
        /// Running speech recognition on the audio.
        case transcribing = "Transcribing"
        /// Transcription complete.
        case complete = "Complete"
    }

    /// The current processing phase.
    public let phase: Phase

    /// Progress within the current activity as a fraction (0.0–1.0).
    ///
    /// During ``Phase/transcribing`` this tracks recognised audio against the
    /// total duration. Phases without a meaningful sub-progress report `0`
    /// (at their start) or `1` (at ``Phase/complete``).
    public let fraction: Double

    /// Creates a progress value.
    ///
    /// - Parameters:
    ///   - phase: The current processing phase.
    ///   - fraction: Progress within the activity (0.0–1.0). Clamped to range.
    public init(phase: Phase, fraction: Double) {
        self.phase = phase
        self.fraction = min(max(fraction, 0), 1)
    }

    /// A human-readable status string suitable for display in UI.
    public var statusText: String {
        switch phase {
        case .downloading:
            return "Downloading..."
        case .extractingAudio:
            return "Extracting audio..."
        case .installingModel:
            return "Installing speech model..."
        case .transcribing:
            return "Transcribing: \(Int(fraction * 100))%"
        case .complete:
            return "Complete"
        }
    }

}
