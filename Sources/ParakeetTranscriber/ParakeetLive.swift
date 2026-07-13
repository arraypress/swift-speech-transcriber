//
//  ParakeetLive.swift
//  ParakeetTranscriber
//
//  Created by David Sherlock on 2026.
//
//  Live microphone transcription with Parakeet, via FluidAudio's cache-aware
//  streaming managers. Emits the shared `LiveTranscriptionEvent` so it matches
//  the Apple and Whisper engines' live API.
//

@preconcurrency import AVFoundation
import Foundation
import SpeechTranscriber
import FluidAudio

public extension ParakeetTranscriber {

    /// Transcribes live microphone audio with Parakeet, emitting interim and
    /// final captions in real time.
    ///
    /// Loads a streaming model, captures the microphone, and feeds audio through
    /// FluidAudio's cache-aware pipeline (resampled to 16 kHz internally). The
    /// rolling partial transcript is emitted as volatile events (`isFinal == false`)
    /// and the complete transcript is emitted as a single final event when the
    /// stream ends. Cancelling the consuming task stops the microphone.
    ///
    /// ```swift
    /// for try await event in ParakeetTranscriber.transcribeLive(model: .englishBalanced) {
    ///     if event.isFinal { transcript = event.text }
    ///     else { liveCaption = event.text }
    /// }
    /// ```
    ///
    /// > Microphone access requires `NSMicrophoneUsageDescription` (and, on
    /// > macOS, the audio-input entitlement). The OS prompts on first use.
    ///
    /// - Parameters:
    ///   - model: The Parakeet streaming model variant.
    ///   - onModelProgress: Called with `0` when the model starts loading and `1`
    ///     once it is ready. FluidAudio's streaming loader does not report a
    ///     download fraction, so this is coarse — surface it as a "loading" state.
    /// - Returns: A throwing stream of ``LiveTranscriptionEvent`` updates.
    static func transcribeLive(
        model: ParakeetStreamModel = .englishBalanced,
        onModelProgress: (@Sendable (Double) -> Void)? = nil
    ) -> AsyncThrowingStream<LiveTranscriptionEvent, Error> {

        AsyncThrowingStream { continuation in
            let task = Task {
                let mic = MicrophoneCapture()
                do {
                    let manager = model.variant.createManager()
                    onModelProgress?(0)
                    try await manager.loadModels()
                    onModelProgress?(1)

                    // FluidAudio's partial transcript is cumulative (decoded from
                    // the whole accumulated token stream), so it grows
                    // monotonically and never wipes earlier text.
                    await manager.setPartialTranscriptCallback { partial in
                        let text = partial.trimmingCharacters(in: .whitespacesAndNewlines)
                        continuation.yield(LiveTranscriptionEvent(
                            text: text, isFinal: false, start: nil, end: nil
                        ))
                    }

                    // Feed microphone audio until cancelled.
                    for await input in mic.stream() {
                        if Task.isCancelled { break }
                        try await manager.appendAudio(input.buffer)
                        try await manager.processBufferedAudio()
                    }
                    mic.stop()

                    // Final transcript.
                    let finalText = try await manager.finish()
                    let text = finalText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        continuation.yield(LiveTranscriptionEvent(
                            text: text, isFinal: true, start: nil, end: nil
                        ))
                    }
                    await manager.cleanup()
                    continuation.finish()
                } catch {
                    mic.stop()
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
