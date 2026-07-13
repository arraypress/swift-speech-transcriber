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
    ///   - onModelProgress: Called with the model download fraction (`0…1`) while
    ///     the model is fetched on first use. The microphone only starts once the
    ///     model has finished loading, so surface this to the user — otherwise a
    ///     large first-time download looks like a hang.
    /// - Returns: A throwing stream of ``LiveTranscriptionEvent`` updates.
    static func transcribeLive(
        model: WhisperModel = .auto,
        language: String? = nil,
        onModelProgress: (@Sendable (Double) -> Void)? = nil
    ) -> AsyncThrowingStream<LiveTranscriptionEvent, Error> {

        AsyncThrowingStream { continuation in
            let holder = LiveStreamHolder()
            let confirmedCount = LiveCounter()

            let task = Task {
                do {
                    let pipe = try await WhisperEngine.loadPipe(model, downloadProgress: onModelProgress)
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
                                    let text = WhisperText.clean(segment.text)
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
                            // Emit the still-unconfirmed tail as a volatile event.
                            //
                            // We deliberately use `unconfirmedSegments` rather than
                            // `currentText`: WhisperKit sets `currentText` to the
                            // placeholder "Waiting for speech..." when idle and
                            // resets it to "" at the end of every decode cycle, both
                            // of which make the live caption flicker/clear. The
                            // unconfirmed segments are the stable rolling tail and
                            // never contain the placeholder.
                            let volatile = newState.unconfirmedSegments
                                .map { WhisperText.clean($0.text) }
                                .filter { !$0.isEmpty }
                                .joined(separator: " ")
                            continuation.yield(LiveTranscriptionEvent(
                                text: volatile, isFinal: false, start: nil, end: nil
                            ))
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
