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

    /// Any other model in the WhisperKit repo, named directly.
    ///
    /// The named cases above are the ones worth putting in a picker; this is
    /// for everything else the repo carries — distilled builds, other
    /// quantizations, and community fine-tunes.
    ///
    /// The reason it exists is accents. The small models degrade sharply on
    /// regional speech, and the right answer is sometimes a specific fine-tune
    /// rather than simply a bigger model — which is a choice only the person
    /// being transcribed can make.
    ///
    /// The value is a glob matched against the repo, exactly as ``modelName``
    /// returns for the built-in cases, so `"large-v3"` and
    /// `"distil-large-v3"` are both valid. An unmatched name fails at load
    /// with WhisperKit's own error rather than silently falling back, so a
    /// typo is visible instead of quietly costing accuracy.
    case custom(String)

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
        // The 632 MB quantized turbo: near-large-v3 accuracy at ~⅕ the size.
        case .largeV3Turbo: return "large-v3-v20240930_turbo_632MB"
        case .custom(let name): return name
        }
    }

    /// All selectable models, for a settings picker.
    ///
    /// Excludes ``auto`` and ``custom(_:)`` — neither is a thing to pick from
    /// a list. A picker offering "custom" without somewhere to type the name
    /// is a dead end.
    public static var all: [WhisperModel] {
        [.tiny, .base, .small, .medium, .largeV3Turbo, .largeV3]
    }

    /// A human-readable name for a model picker.
    public var displayName: String {
        switch self {
        case .auto: return "Automatic"
        case .tiny: return "Tiny"
        case .base: return "Base"
        case .small: return "Small"
        case .medium: return "Medium"
        case .largeV3: return "Large v3"
        case .largeV3Turbo: return "Large v3 Turbo"
        case .custom(let name): return name
        }
    }

    /// The approximate download size in megabytes, or `nil` for ``auto``.
    ///
    /// Show this next to each option so users know the cost before downloading.
    public var approximateDownloadMB: Int? {
        switch self {
        case .auto: return nil
        case .tiny: return 77
        case .base: return 147
        case .small: return 486
        case .medium: return 1_530
        case .largeV3Turbo: return 646
        case .largeV3: return 3_090
        // Unknowable without asking the repo, and a wrong figure next to a
        // download button is worse than none.
        case .custom: return nil
        }
    }
}
