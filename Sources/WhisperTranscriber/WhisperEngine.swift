//
//  WhisperEngine.swift
//  WhisperTranscriber
//
//  Created by David Sherlock on 2026.
//
//  The only file that imports WhisperKit. Refers to our progress type via the
//  `EngineProgress` alias to avoid the name collision with WhisperKit's own
//  `TranscriptionProgress`.

@preconcurrency import AVFoundation
import Foundation
import SpeechTranscriber
import WhisperKit

/// Runs WhisperKit against a local audio file and maps the result into a
/// shared ``Transcript``.
enum WhisperEngine {

    /// Loads a WhisperKit pipeline for the given model, downloading on first use.
    static func loadPipe(_ model: WhisperModel) async throws -> WhisperKit {
        do {
            if let modelName = model.modelName {
                return try await WhisperKit(WhisperKitConfig(model: modelName))
            }
            return try await WhisperKit()
        } catch {
            throw TranscriptionError.modelInstallationFailed(error.localizedDescription)
        }
    }

    static func run(
        localFile url: URL,
        model: WhisperModel,
        language: String?,
        translate: Bool,
        progress: (@Sendable (EngineProgress) -> Void)?
    ) async throws -> Transcript {

        // MARK: Load Model (downloads on first use)

        progress?(EngineProgress(phase: .installingModel, fraction: 0))
        let pipe = try await loadPipe(model)

        // MARK: Audio Duration

        let audioFile = try? AVAudioFile(forReading: url)
        let fileDuration = audioFile.map { Double($0.length) / $0.processingFormat.sampleRate } ?? 0

        // MARK: Transcribe

        progress?(EngineProgress(phase: .transcribing, fraction: 0))
        let startedAt = Date()

        let results: [TranscriptionResult]
        do {
            var options = DecodingOptions()
            options.language = language
            if translate { options.task = .translate }
            results = try await pipe.transcribe(audioPath: url.path, decodeOptions: options)
        } catch {
            throw TranscriptionError.transcriptionFailed(error.localizedDescription)
        }

        // MARK: Map Segments

        var segments: [TranscriptSegment] = []
        var segmentId = 0
        for result in results {
            for segment in result.segments {
                let text = WhisperText.clean(segment.text)
                guard !text.isEmpty else { continue }
                segmentId += 1
                segments.append(TranscriptSegment(
                    id: segmentId,
                    text: text,
                    start: Double(segment.start),
                    end: Double(segment.end)
                ))
            }
        }

        let transcriptionTime = Date().timeIntervalSince(startedAt)
        progress?(EngineProgress(phase: .complete, fraction: 1))

        guard !segments.isEmpty else { throw TranscriptionError.emptyTranscript }

        let duration = fileDuration > 0 ? fileDuration : (segments.last?.end ?? 0)
        let localeIdentifier = results.first?.language ?? language ?? "en"

        return Transcript(
            segments: segments,
            audioDuration: duration,
            transcriptionTime: transcriptionTime,
            localeIdentifier: localeIdentifier
        )
    }
}
