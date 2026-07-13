//
//  ParakeetEngine.swift
//  ParakeetTranscriber
//
//  Created by David Sherlock on 2026.
//
//  The only file that imports FluidAudio. Maps a Parakeet transcription into
//  the shared ``Transcript`` type.
//

@preconcurrency import AVFoundation
import Foundation
import SpeechTranscriber
import FluidAudio

/// Runs FluidAudio's Parakeet pipeline against a local audio file and maps the
/// result into a shared ``Transcript``.
enum ParakeetEngine {

    /// Downloads (on first use) and loads a Parakeet model, reporting download
    /// progress, then returns a ready-to-use `AsrManager`.
    ///
    /// - Parameters:
    ///   - model: The Parakeet model variant.
    ///   - downloadProgress: Called with the model download fraction (`0…1`).
    ///     The models are large on first download, so surface this to the user.
    static func loadManager(
        _ model: ParakeetModel,
        downloadProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> AsrManager {
        do {
            let models = try await AsrModels.downloadAndLoad(
                version: model.version,
                progressHandler: { progress in
                    downloadProgress?(progress.fractionCompleted)
                }
            )
            let manager = AsrManager()
            try await manager.loadModels(models)
            return manager
        } catch {
            throw TranscriptionError.modelInstallationFailed(error.localizedDescription)
        }
    }

    static func run(
        localFile url: URL,
        model: ParakeetModel,
        language: String?,
        progress: (@Sendable (TranscriptionProgress) -> Void)?
    ) async throws -> Transcript {

        // MARK: Load Model (downloads on first use)

        progress?(TranscriptionProgress(phase: .installingModel, fraction: 0))
        let manager = try await loadManager(model, downloadProgress: { fraction in
            progress?(TranscriptionProgress(phase: .installingModel, fraction: fraction))
        })

        // MARK: Audio Duration

        let audioFile = try? AVAudioFile(forReading: url)
        let fileDuration = audioFile.map { Double($0.length) / $0.processingFormat.sampleRate } ?? 0

        // MARK: Transcribe

        progress?(TranscriptionProgress(phase: .transcribing, fraction: 0))

        let result: ASRResult
        do {
            var decoderState = try TdtDecoderState()
            let forcedLanguage = language.flatMap { Language(rawValue: $0) }
            result = try await manager.transcribe(url, decoderState: &decoderState, language: forcedLanguage)
        } catch {
            throw TranscriptionError.transcriptionFailed(error.localizedDescription)
        }

        // MARK: Map Segments

        let duration = fileDuration > 0 ? fileDuration : result.duration
        let segments = ParakeetText.segments(
            from: result.tokenTimings,
            fallbackText: result.text,
            duration: duration
        )

        progress?(TranscriptionProgress(phase: .complete, fraction: 1))

        guard !segments.isEmpty else { throw TranscriptionError.emptyTranscript }

        let localeIdentifier = language ?? (model == .multilingualV3 ? "und" : "en")

        return Transcript(
            segments: segments,
            audioDuration: duration,
            transcriptionTime: result.processingTime,
            localeIdentifier: localeIdentifier
        )
    }
}
