//
//  MicrophoneCapture.swift
//  SpeechTranscriber
//
//  Created by David Sherlock on 2026.
//

@preconcurrency import AVFoundation

/// Captures microphone audio as a stream of ``AudioInput`` for live transcription.
///
/// A thin convenience over `AVAudioEngine` that installs a tap on the input
/// node and yields each captured buffer. Pair it with
/// ``SpeechTranscriber/transcribe(audioInput:options:)`` for live captions.
///
/// ```swift
/// let mic = try MicrophoneCapture()
/// let stream = mic.stream()
/// for try await event in SpeechTranscriber.transcribe(audioInput: stream) {
///     caption = event.text
/// }
/// mic.stop()
/// ```
///
/// > Important: Microphone access requires the `NSMicrophoneUsageDescription`
/// > key in your app's Info.plist and, on macOS, the audio-input sandbox
/// > entitlement. The OS prompts the user for permission on first use.
public final class MicrophoneCapture {

    private let engine = AVAudioEngine()
    private let bufferSize: AVAudioFrameCount
    /// Held so ``stop()`` can END the stream, not merely silence it.
    ///
    /// Stopping the audio engine alone leaves the `AsyncStream` open forever: a transcriber
    /// awaiting it never sees the input finish, so it never emits its trailing final result. For
    /// push-to-talk — where the whole utterance is short and the last words matter — that reads
    /// as "nothing was heard".
    private var continuation: AsyncStream<AudioInput>.Continuation?

    /// Creates a microphone capture source.
    ///
    /// - Parameter bufferSize: The tap buffer size in frames. Default `4096`.
    public init(bufferSize: AVAudioFrameCount = 4096) {
        self.bufferSize = bufferSize
    }

    /// Starts capturing and returns a stream of captured audio buffers.
    ///
    /// The stream ends when ``stop()`` is called or the engine stops. Starting
    /// a new stream replaces any previous tap.
    ///
    /// - Returns: A stream of ``AudioInput`` values.
    public func stream() -> AsyncStream<AudioInput> {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        return AsyncStream { continuation in
            self.continuation = continuation
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: bufferSize, format: format) { buffer, _ in
                continuation.yield(AudioInput(buffer))
            }

            engine.prepare()
            do {
                try engine.start()
            } catch {
                continuation.finish()
                return
            }

            continuation.onTermination = { [engine] _ in
                engine.inputNode.removeTap(onBus: 0)
                engine.stop()
            }
        }
    }

    /// Stops capturing, tears down the audio tap, and finishes the stream.
    ///
    /// Finishing matters: a consumer awaiting the audio needs the input to END before it can
    /// flush its last result. Without it a short utterance is silently dropped.
    public func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        continuation?.finish()
        continuation = nil
    }
}
