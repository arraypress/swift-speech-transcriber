//
//  WhisperModel.swift
//  WhisperTranscriber
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// The Whisper model variant to use for transcription.
///
/// Larger models are more accurate but slower and use more memory. ``auto``
/// lets WhisperKit pick the best model for the current device.
///
/// ```swift
/// // Highest quality, recommended on Mac
/// try await WhisperTranscriber.transcribe(audioURL: url, model: .largeV3Turbo)
///
/// // Let WhisperKit choose based on the device
/// try await WhisperTranscriber.transcribe(audioURL: url, model: .auto)
/// ```
public enum WhisperModel: Sendable {

    /// Let WhisperKit select the recommended model for this device.
    case auto

    /// Tiny model — fastest, lowest accuracy.
    case tiny

    /// Base model.
    case base

    /// Small model — a good speed/accuracy balance on iOS.
    case small

    /// Medium model.
    case medium

    /// Large v3 — highest accuracy, heaviest.
    case largeV3

    /// Large v3 Turbo — near large-v3 accuracy, much faster. Recommended on Mac.
    case largeV3Turbo

    /// The WhisperKit model identifier (a glob matched against the model repo),
    /// or `nil` to let WhisperKit choose.
    var modelName: String? {
        switch self {
        case .auto: return nil
        case .tiny: return "tiny"
        case .base: return "base"
        case .small: return "small"
        case .medium: return "medium"
        case .largeV3: return "large-v3"
        case .largeV3Turbo: return "large-v3-v20240930_turbo"
        }
    }
}
