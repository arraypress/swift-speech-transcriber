//
//  WhisperModels.swift
//  WhisperTranscriber
//
//  Created by David Sherlock on 2026.
//
//  Model management: discover what's available, what's recommended for this
//  device, and pre-download a model with progress. Imports WhisperKit, so it
//  refers to nothing from SpeechTranscriber that would collide.

import Foundation
import SpeechTranscriber
import WhisperKit

public extension WhisperTranscriber {

    /// The model WhisperKit recommends for the current device.
    ///
    /// Use this to resolve ``WhisperModel/auto`` for display, or as a sensible
    /// default selection in a picker.
    static func recommendedModelName() -> String {
        WhisperKit.recommendedModels().default
    }

    /// The model identifiers WhisperKit considers usable on this device.
    static func supportedModelNames() -> [String] {
        WhisperKit.recommendedModels().supported
    }

    /// Pre-downloads (and caches) a model so the first transcription doesn't
    /// pay the download cost.
    ///
    /// Call this from a settings screen with a progress bar. No-op work if the
    /// model is already cached.
    ///
    /// ```swift
    /// try await WhisperTranscriber.prepare(model: .largeV3Turbo) { fraction in
    ///     downloadProgress = fraction   // 0.0 … 1.0
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - model: The model to download. ``WhisperModel/auto`` resolves to the
    ///     device-recommended model.
    ///   - progress: An optional download-progress callback (0–1).
    /// - Throws: ``TranscriptionError/modelInstallationFailed(_:)`` on failure.
    static func prepare(
        model: WhisperModel = .auto,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws {
        let variant = model.modelName ?? recommendedModelName()
        do {
            _ = try await WhisperKit.download(variant: variant, progressCallback: { p in
                progress?(p.fractionCompleted)
            })
        } catch {
            throw TranscriptionError.modelInstallationFailed(error.localizedDescription)
        }
    }
}
