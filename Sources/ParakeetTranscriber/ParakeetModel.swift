//
//  ParakeetModel.swift
//  ParakeetTranscriber
//
//  Created by David Sherlock on 2026.
//

import Foundation
import FluidAudio

/// The NVIDIA Parakeet model variant to use for transcription.
///
/// Parakeet runs on-device via CoreML on the Apple Neural Engine — fast and
/// power-efficient, which makes it well suited to real-time dictation. ``v2``
/// is English-only and tops the English accuracy leaderboards; ``v3`` adds
/// ~25 European languages at a small accuracy cost.
///
/// ```swift
/// // English, fastest + most accurate for English
/// let transcript = try await ParakeetTranscriber.transcribe(audioURL: url, model: .v2)
///
/// // Multilingual (European languages)
/// let transcript = try await ParakeetTranscriber.transcribe(audioURL: url, model: .v3)
/// ```
public enum ParakeetModel: Sendable {

    /// Parakeet TDT 0.6B v2 — English only, highest English accuracy.
    case englishV2

    /// Parakeet TDT 0.6B v3 — multilingual (~25 European languages).
    case multilingualV3

    /// The recommended default (English v2).
    public static let auto: ParakeetModel = .englishV2

    /// The underlying FluidAudio model version.
    var version: AsrModelVersion {
        switch self {
        case .englishV2: return .v2
        case .multilingualV3: return .v3
        }
    }

    /// All selectable models, for a settings picker.
    public static var all: [ParakeetModel] {
        [.englishV2, .multilingualV3]
    }

    /// A human-readable name for a model picker.
    public var displayName: String {
        switch self {
        case .englishV2: return "Parakeet v2 (English)"
        case .multilingualV3: return "Parakeet v3 (Multilingual)"
        }
    }

    /// The approximate download size in megabytes.
    ///
    /// Show this next to each option so users know the cost before downloading.
    public var approximateDownloadMB: Int {
        switch self {
        case .englishV2: return 600
        case .multilingualV3: return 650
        }
    }
}

/// The Parakeet **streaming** model variant for live transcription.
///
/// Live transcription uses FluidAudio's cache-aware streaming engines rather
/// than the offline batch models (``ParakeetModel``), so the choices differ:
/// the English EOU (end-of-utterance) models are small and low-latency, while
/// the Nemotron model is multilingual at higher latency.
///
/// ```swift
/// for try await event in ParakeetTranscriber.transcribeLive(model: .englishBalanced) {
///     caption = event.text
/// }
/// ```
public enum ParakeetStreamModel: Sendable {

    /// Parakeet EOU 120M, 160 ms chunks — lowest latency (English).
    case englishLowLatency

    /// Parakeet EOU 120M, 320 ms chunks — balanced latency/accuracy (English).
    case englishBalanced

    /// Nemotron 0.6B streaming — multilingual, higher latency.
    case multilingual

    /// The underlying FluidAudio streaming variant.
    var variant: StreamingModelVariant {
        switch self {
        case .englishLowLatency: return .parakeetEou160ms
        case .englishBalanced: return .parakeetEou320ms
        case .multilingual: return .nemotron1120ms
        }
    }

    /// All selectable streaming models, for a settings picker.
    public static var all: [ParakeetStreamModel] {
        [.englishLowLatency, .englishBalanced, .multilingual]
    }

    /// A human-readable name for a model picker.
    public var displayName: String {
        switch self {
        case .englishLowLatency: return "Parakeet EOU (160 ms, English)"
        case .englishBalanced: return "Parakeet EOU (320 ms, English)"
        case .multilingual: return "Nemotron (Multilingual)"
        }
    }
}
