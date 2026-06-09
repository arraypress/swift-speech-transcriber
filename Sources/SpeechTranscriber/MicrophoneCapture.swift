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

    /// Stops capturing and tears down the audio tap.
    public func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }
}
