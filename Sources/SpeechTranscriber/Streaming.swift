//
//  Streaming.swift
//  SpeechTranscriber
//
//  Created by David Sherlock on 2026.
//

@preconcurrency import AVFoundation
import Foundation
import Speech

public extension SpeechTranscriber {

    /// Transcribes a live stream of audio, emitting interim and final results.
    ///
    /// Feed captured audio (from a microphone, system audio, or a file read in
    /// chunks) as ``AudioInput`` values and receive a stream of
    /// ``LiveTranscriptionEvent`` updates. Interim (volatile) events arrive
    /// rapidly and may change; final events are stable. The engine handles
    /// resampling each buffer to the analyzer's required format.
    ///
    /// The result stream finishes when the input stream finishes and the engine
    /// has finalised the trailing audio. Cancelling the consuming task stops
    /// transcription.
    ///
    /// ```swift
    /// let mic = try MicrophoneCapture()
    /// for try await event in SpeechTranscriber.transcribe(audioInput: mic.stream()) {
    ///     caption = event.text          // live, updating
    ///     if event.isFinal { transcript += event.text + " " }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - audioInput: A stream of captured audio buffers.
    ///   - options: Transcription configuration (locale). Default ``TranscriptionOptions()``.
    /// - Returns: A throwing stream of ``LiveTranscriptionEvent`` updates.
    static func transcribe(
        audioInput: AsyncStream<AudioInput>,
        options: TranscriptionOptions = TranscriptionOptions()
    ) -> AsyncThrowingStream<LiveTranscriptionEvent, Error> {

        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard isAvailable else { throw TranscriptionError.unavailable }

                    let transcriber = try await makeTranscriber(
                        locale: options.locale,
                        volatileResults: true,
                        progress: nil
                    )
                    let analyzer = SpeechAnalyzer(modules: [transcriber])
                    try await applyVocabulary(options.vocabulary, to: analyzer)

                    let (inputSequence, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()
                    try await analyzer.start(inputSequence: inputSequence)

                    // Reader: surface recognition results as events.
                    let reader = Task {
                        for try await result in transcriber.results {
                            let text = String(result.text.characters)
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            let ranges = result.text.runs.compactMap { $0.audioTimeRange }
                            continuation.yield(LiveTranscriptionEvent(
                                text: text,
                                isFinal: result.isFinal,
                                start: ranges.first?.start.seconds,
                                end: ranges.last?.end.seconds
                            ))
                        }
                    }

                    // Feeder: resample incoming buffers and push to the analyzer.
                    let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
                    var converter: AVAudioConverter?

                    for await input in audioInput {
                        let buffer = input.buffer
                        let prepared: AVAudioPCMBuffer
                        if let analyzerFormat, buffer.format != analyzerFormat {
                            if converter == nil {
                                converter = AVAudioConverter(from: buffer.format, to: analyzerFormat)
                            }
                            prepared = Self.resample(buffer, with: converter, to: analyzerFormat) ?? buffer
                        } else {
                            prepared = buffer
                        }
                        inputBuilder.yield(AnalyzerInput(buffer: prepared))
                    }

                    inputBuilder.finish()
                    try await analyzer.finalizeAndFinishThroughEndOfInput()
                    try await reader.value
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Resamples a PCM buffer to a target format using `AVAudioConverter`.
    ///
    /// - Returns: The converted buffer, or `nil` if conversion fails.
    private static func resample(
        _ buffer: AVAudioPCMBuffer,
        with converter: AVAudioConverter?,
        to format: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        guard let converter else { return nil }

        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1024
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
            return nil
        }

        var consumed = false
        var conversionError: NSError?
        converter.convert(to: output, error: &conversionError) { _, statusPointer in
            if consumed {
                statusPointer.pointee = .noDataNow
                return nil
            }
            consumed = true
            statusPointer.pointee = .haveData
            return buffer
        }

        return conversionError == nil ? output : nil
    }

}
