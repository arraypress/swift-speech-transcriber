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
import CoreML
import Foundation
import SpeechTranscriber
import WhisperKit

/// Holds the most recently loaded pipeline so repeat transcriptions don't reload it.
///
/// A lock rather than an actor: `WhisperKit` is not `Sendable`, so an actor could not hand it back
/// out. The lock covers the cache's own state; the pipeline itself is used by one transcription at
/// a time, which is how both the file and live entry points drive it.
private final class PipeCache: @unchecked Sendable {

    struct Key: Equatable {
        let model: String
        let useNeuralEngine: Bool
    }

    static let shared = PipeCache()

    private let lock = NSLock()
    private var key: Key?
    private var cached: WhisperKit?

    func pipe(for key: Key) -> WhisperKit? {
        lock.lock()
        defer { lock.unlock() }
        return self.key == key ? cached : nil
    }

    func store(_ pipe: WhisperKit, for key: Key) {
        lock.lock()
        defer { lock.unlock() }
        self.key = key
        cached = pipe
    }
}

/// Runs WhisperKit against a local audio file and maps the result into a
/// shared ``Transcript``.
enum WhisperEngine {

    /// Loads a WhisperKit pipeline for the given model, downloading on first use.
    ///
    /// The download and the load are split into two steps so callers can observe
    /// download progress: ``WhisperKit/download(variant:downloadBase:useBackgroundSession:from:token:endpoint:progressCallback:)``
    /// reports `0…1` as model files arrive (and returns immediately if already
    /// cached), then the pipeline is loaded from that local folder.
    ///
    /// - Parameter downloadProgress: Called with the download fraction (`0…1`).
    ///   Not invoked for ``WhisperModel/auto`` (which resolves and downloads
    ///   internally).
    /// Loads a pipeline, reusing the last one if it matches.
    ///
    /// Loading is expensive — tens of seconds for the larger models, and minutes the first time
    /// the Neural Engine specializes one. Live/push-to-talk callers start a fresh stream for every
    /// utterance, so without this each one would pay that cost again and the feature simply
    /// wouldn't work. Only the most recent pipeline is held: callers keep to one model at a time,
    /// and these are hundreds of megabytes resident.
    static func cachedPipe(
        _ model: WhisperModel,
        useNeuralEngine: Bool = true,
        downloadProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> WhisperKit {
        let key = PipeCache.Key(model: model.modelName ?? "auto", useNeuralEngine: useNeuralEngine)
        if let pipe = PipeCache.shared.pipe(for: key) { return pipe }
        let pipe = try await loadPipe(model, useNeuralEngine: useNeuralEngine,
                                      downloadProgress: downloadProgress)
        PipeCache.shared.store(pipe, for: key)
        return pipe
    }

    static func loadPipe(
        _ model: WhisperModel,
        useNeuralEngine: Bool = true,
        downloadProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> WhisperKit {
        // The ANE gives the fastest inference but its compiler specializes
        // the model per app on first load, which can take minutes. CPU+GPU
        // loads near-instantly at somewhat slower inference — the right
        // trade for interactive apps.
        let computeOptions = useNeuralEngine ? nil : ModelComputeOptions(
            melCompute: .cpuAndGPU,
            audioEncoderCompute: .cpuAndGPU,
            textDecoderCompute: .cpuAndGPU
        )
        do {
            guard let modelName = model.modelName else {
                // `.auto` lets WhisperKit pick + fetch a recommended model itself;
                // no granular progress is available for that path.
                return try await WhisperKit(WhisperKitConfig(computeOptions: computeOptions))
            }
            let folder = try await WhisperKit.download(
                variant: modelName,
                progressCallback: { progress in
                    downloadProgress?(progress.fractionCompleted)
                }
            )
            let config = WhisperKitConfig(
                model: modelName,
                modelFolder: folder.path,
                computeOptions: computeOptions,
                download: false
            )
            return try await WhisperKit(config)
        } catch {
            throw TranscriptionError.modelInstallationFailed(error.localizedDescription)
        }
    }

    static func run(
        localFile url: URL,
        model: WhisperModel,
        language: String?,
        translate: Bool,
        vocabulary: [String] = [],
        segmentation: Segmentation = .sentence,
        useNeuralEngine: Bool = true,
        progress: (@Sendable (EngineProgress) -> Void)?
    ) async throws -> Transcript {

        // MARK: Load Model (downloads on first use)

        progress?(EngineProgress(phase: .installingModel, fraction: 0))
        let pipe = try await cachedPipe(model, useNeuralEngine: useNeuralEngine, downloadProgress: { fraction in
            progress?(EngineProgress(phase: .installingModel, fraction: fraction))
        })

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
            options.wordTimestamps = segmentation == .word
            // Bias the decoder toward custom vocabulary by seeding the prompt.
            if !vocabulary.isEmpty, let tokenizer = pipe.tokenizer {
                let prompt = "Glossary: " + vocabulary.joined(separator: ", ") + "."
                options.promptTokens = tokenizer.encode(text: prompt)
                options.usePrefillPrompt = true
            }
            results = try await pipe.transcribe(audioPath: url.path, decodeOptions: options)
        } catch {
            throw TranscriptionError.transcriptionFailed(error.localizedDescription)
        }

        // MARK: Map Segments

        var segments: [TranscriptSegment] = []
        var segmentId = 0
        for result in results {
            for segment in result.segments {
                switch segmentation {
                case .sentence:
                    let text = WhisperText.clean(segment.text)
                    guard !text.isEmpty else { continue }
                    segmentId += 1
                    segments.append(TranscriptSegment(
                        id: segmentId,
                        text: text,
                        start: Double(segment.start),
                        end: Double(segment.end)
                    ))
                case .word:
                    for word in segment.words ?? [] {
                        let text = WhisperText.clean(word.word)
                        guard !text.isEmpty else { continue }
                        segmentId += 1
                        segments.append(TranscriptSegment(
                            id: segmentId,
                            text: text,
                            start: Double(word.start),
                            end: Double(word.end)
                        ))
                    }
                }
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
