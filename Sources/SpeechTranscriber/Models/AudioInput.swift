//
//  AudioInput.swift
//  SpeechTranscriber
//
//  Created by David Sherlock on 2026.
//

import AVFoundation

/// A single chunk of captured audio handed to live transcription.
///
/// Wraps an `AVAudioPCMBuffer` so it can be sent across concurrency domains.
/// `AVAudioPCMBuffer` is a reference type that the audio framework does not
/// mark `Sendable`; this wrapper is safe in practice because each captured
/// buffer is produced fresh and not mutated after being handed off.
///
/// ```swift
/// // From a microphone tap, a file read, or a system-audio source
/// continuation.yield(AudioInput(pcmBuffer))
/// ```
public struct AudioInput: @unchecked Sendable {

    /// The PCM audio buffer.
    public let buffer: AVAudioPCMBuffer

    /// Wraps a PCM buffer for delivery to live transcription.
    ///
    /// - Parameter buffer: A freshly captured PCM buffer. Do not mutate it
    ///   after passing it in.
    public init(_ buffer: AVAudioPCMBuffer) {
        self.buffer = buffer
    }
}
