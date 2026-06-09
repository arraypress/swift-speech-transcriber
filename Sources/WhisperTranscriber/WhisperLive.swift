//
//  WhisperLive.swift
//  WhisperTranscriber
//
//  Created by David Sherlock on 2026.
//
//  Live microphone transcription with Whisper, via WhisperKit's
//  `AudioStreamTranscriber`. Emits the shared `LiveTranscriptionEvent` so it
//  matches the Apple engine's live API.

import Foundation
import SpeechTranscriber
import WhisperKit

public extension WhisperTranscriber {

    /// Transcribes live microphone audio with Whisper, emitting interim and
    /// final captions in real time.
    ///
    /// Loads the model, then streams from the microphone through WhisperKit's
    /// real-time pipeline (with voice-activity detection). Volatile events
    /// (`isFinal == false`) update as you speak; confirmed segments arrive as
    /// final events. Cancelling the consuming task stops the microphone.
    ///
    /// ```swift
    /// for try await event in WhisperTranscriber.transcribeLive(model: .small) {
    ///     if event.isFinal { transcript += event.text + " " }
    ///     else { liveCaption = event.text }
    /// }
    /// ```
    ///
    /// > Microphone access requires `NSMicrophoneUsageDescription` (and, on
    /// > macOS, the audio-input entitlement). The OS prompts on first use.
    ///
    /// - Parameters:
    ///   - model: The Whisper model variant. Smaller models keep up better live.
    ///   - language: An ISO language code to force, or `nil` to auto-detect.
    /// - Returns: A throwing stream of ``LiveTranscriptionEvent`` updates.
    static func transcribeLive(
        model: WhisperModel = .auto,
        language: String? = nil
    ) -> AsyncThrowingStream<LiveTranscriptionEvent, Error> {

        AsyncThrowingStream { continuation in
            let holder = LiveStreamHolder()
            let confirmedCount = LiveCounter()

            let task = Task {
                do {
                    let pipe = try await WhisperEngine.loadPipe(model)
                    guard let tokenizer = pipe.tokenizer else {
                        throw TranscriptionError.modelInstallationFailed("Tokenizer unavailable after model load.")
                    }

                    var options = DecodingOptions()
                    options.language = language

                    let stream = AudioStreamTranscriber(
                        audioEncoder: pipe.audioEncoder,
                        featureExtractor: pipe.featureExtractor,
                        segmentSeeker: pipe.segmentSeeker,
                        textDecoder: pipe.textDecoder,
                        tokenizer: tokenizer,
                        audioProcessor: pipe.audioProcessor,
                        decodingOptions: options,
                        stateChangeCallback: { _, newState in
                            // Emit newly confirmed segments as final events.
                            let confirmed = newState.confirmedSegments
                            let already = confirmedCount.value
                            if confirmed.count > already {
                                for segment in confirmed[already...] {
                                    let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
                                    guard !text.isEmpty else { continue }
                                    continuation.yield(LiveTranscriptionEvent(
                                        text: text,
                                        isFinal: true,
                                        start: Double(segment.start),
                                        end: Double(segment.end)
                                    ))
                                }
                                confirmedCount.value = confirmed.count
                            }
                            // Emit the rolling, still-changing text as a volatile event.
                            let volatile = newState.currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !volatile.isEmpty {
                                continuation.yield(LiveTranscriptionEvent(
                                    text: volatile, isFinal: false, start: nil, end: nil
                                ))
                            }
                        }
                    )
                    holder.stream = stream

                    try await stream.startStreamTranscription()  // runs until stopped
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
                let stream = holder.stream
                Task { await stream?.stopStreamTranscription() }
            }
        }
    }
}

/// Holds the actor so the stream's `onTermination` can stop the microphone.
private final class LiveStreamHolder: @unchecked Sendable {
    var stream: AudioStreamTranscriber?
}

/// Tracks how many confirmed segments have already been emitted as final events.
private final class LiveCounter: @unchecked Sendable {
    var value = 0
}
