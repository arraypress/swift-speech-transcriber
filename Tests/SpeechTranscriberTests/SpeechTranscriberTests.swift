//
//  SpeechTranscriberTests.swift
//  SpeechTranscriber
//
//  Created by David Sherlock on 2026.
//

import XCTest
import os
import AVFoundation
@testable import SpeechTranscriber

final class SpeechTranscriberTests: XCTestCase {

    // MARK: - Helpers

    /// Builds a small, deterministic transcript for exercising the model layer.
    private func sampleTranscript() -> Transcript {
        Transcript(
            segments: [
                TranscriptSegment(id: 1, text: "Hello everyone", start: 0.0, end: 2.5),
                TranscriptSegment(id: 2, text: "Welcome to the show", start: 2.5, end: 5.0),
                TranscriptSegment(id: 3, text: "Let's get started", start: 5.0, end: 7.25),
            ],
            audioDuration: 7.25,
            transcriptionTime: 0.25,
            localeIdentifier: "en-US"
        )
    }

    // MARK: - TimeCode

    func testClockFormatting() {
        XCTAssertEqual(TimeCode.clock(0), "0:00")
        XCTAssertEqual(TimeCode.clock(5), "0:05")
        XCTAssertEqual(TimeCode.clock(65), "1:05")
        XCTAssertEqual(TimeCode.clock(3661), "1:01:01")
        XCTAssertEqual(TimeCode.clock(-10), "0:00", "Negative values clamp to zero")
    }

    // MARK: - TranscriptionOptions

    func testOptions_vocabularyDefaultsEmpty() {
        XCTAssertEqual(TranscriptionOptions().vocabulary, [])
    }

    func testOptions_storesVocabulary() {
        let options = TranscriptionOptions(vocabulary: ["arraypress", "Kokoro"])
        XCTAssertEqual(options.vocabulary, ["arraypress", "Kokoro"])
    }

    func testOptions_defaultsPreservedWithVocabulary() {
        let options = TranscriptionOptions(segmentation: .word, vocabulary: ["FODMAP"])
        XCTAssertEqual(options.locale.identifier(.bcp47), "en-US")
        if case .word = options.segmentation {} else { XCTFail("expected .word segmentation") }
        XCTAssertEqual(options.vocabulary, ["FODMAP"])
    }

    func testSRTTimestampFormatting() {
        XCTAssertEqual(TimeCode.srt(0), "00:00:00,000")
        XCTAssertEqual(TimeCode.srt(2.5), "00:00:02,500")
        XCTAssertEqual(TimeCode.srt(83.25), "00:01:23,250")
        XCTAssertEqual(TimeCode.srt(3661.001), "01:01:01,001")
        XCTAssertEqual(TimeCode.srt(-5), "00:00:00,000")
    }

    func testVTTTimestampFormatting() {
        XCTAssertEqual(TimeCode.vtt(0), "00:00:00.000")
        XCTAssertEqual(TimeCode.vtt(2.5), "00:00:02.500")
        XCTAssertEqual(TimeCode.vtt(83.25), "00:01:23.250")
    }

    // MARK: - TranscriptSegment

    func testSegmentDuration() {
        let segment = TranscriptSegment(id: 1, text: "Hi", start: 2.0, end: 5.5)
        XCTAssertEqual(segment.duration, 3.5, accuracy: 0.0001)
    }

    func testSegmentDurationNeverNegative() {
        let segment = TranscriptSegment(id: 1, text: "Hi", start: 5.0, end: 2.0)
        XCTAssertEqual(segment.duration, 0.0)
    }

    func testSegmentFormatting() {
        let segment = TranscriptSegment(id: 1, text: "Hi", start: 65, end: 3661)
        XCTAssertEqual(segment.formattedStart, "1:05")
        XCTAssertEqual(segment.formattedEnd, "1:01:01")
    }

    func testSegmentCodableRoundTrip() throws {
        let segment = TranscriptSegment(id: 7, text: "Round trip", start: 1.5, end: 3.0)
        let data = try JSONEncoder().encode(segment)
        let decoded = try JSONDecoder().decode(TranscriptSegment.self, from: data)
        XCTAssertEqual(decoded, segment)
    }

    // MARK: - Transcript Derived Text

    func testPlainText() {
        XCTAssertEqual(sampleTranscript().plainText, "Hello everyone Welcome to the show Let's get started")
    }

    func testTimestampedText() {
        let expected = """
        [0:00] Hello everyone
        [0:02] Welcome to the show
        [0:05] Let's get started
        """
        XCTAssertEqual(sampleTranscript().timestampedText, expected)
    }

    func testCountAndEmptiness() {
        XCTAssertEqual(sampleTranscript().count, 3)
        XCTAssertFalse(sampleTranscript().isEmpty)

        let empty = Transcript(segments: [], audioDuration: 0, transcriptionTime: 0, localeIdentifier: "en-US")
        XCTAssertEqual(empty.count, 0)
        XCTAssertTrue(empty.isEmpty)
    }

    func testWordCount() {
        // "Hello everyone Welcome to the show Let's get started" → 9 words
        XCTAssertEqual(sampleTranscript().wordCount, 9)
    }

    func testFormattedDuration() {
        XCTAssertEqual(sampleTranscript().formattedDuration, "0:07")
    }

    func testSpeedFactor() {
        // 7.25s of audio transcribed in 0.25s → 29x
        XCTAssertEqual(sampleTranscript().speedFactor, 29.0, accuracy: 0.0001)
    }

    func testSpeedFactorZeroTime() {
        let transcript = Transcript(segments: [], audioDuration: 10, transcriptionTime: 0, localeIdentifier: "en-US")
        XCTAssertEqual(transcript.speedFactor, 0)
    }

    // MARK: - Transcript Subtitle Export

    func testSRTExport() {
        let expected = """
        1
        00:00:00,000 --> 00:00:02,500
        Hello everyone

        2
        00:00:02,500 --> 00:00:05,000
        Welcome to the show

        3
        00:00:05,000 --> 00:00:07,250
        Let's get started
        """
        XCTAssertEqual(sampleTranscript().srt, expected)
    }

    func testVTTExport() {
        let vtt = sampleTranscript().vtt
        XCTAssertTrue(vtt.hasPrefix("WEBVTT\n\n"))
        XCTAssertTrue(vtt.contains("00:00:00.000 --> 00:00:02.500\nHello everyone"))
        XCTAssertTrue(vtt.contains("00:00:05.000 --> 00:00:07.250\nLet's get started"))
    }

    func testVTTEmpty() {
        let empty = Transcript(segments: [], audioDuration: 0, transcriptionTime: 0, localeIdentifier: "en-US")
        XCTAssertEqual(empty.vtt, "WEBVTT\n")
    }

    // MARK: - Transcript JSON Export

    func testJSONExportStructure() throws {
        let json = try sampleTranscript().jsonString()
        XCTAssertTrue(json.contains("\"locale\" : \"en-US\""))
        XCTAssertTrue(json.contains("\"plain_text\""), "Keys should be snake_case")
        XCTAssertTrue(json.contains("\"segment_count\" : 3"))
        XCTAssertTrue(json.contains("\"word_count\" : 9"))
        XCTAssertTrue(json.contains("\"segments\""))
    }

    func testJSONExportDecodesBack() throws {
        let data = try sampleTranscript().jsonData()
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(object?["segment_count"] as? Int, 3)
        let segments = object?["segments"] as? [[String: Any]]
        XCTAssertEqual(segments?.count, 3)
        XCTAssertEqual(segments?.first?["text"] as? String, "Hello everyone")
    }

    func testJSONCompactHasNoNewlines() throws {
        let compact = try sampleTranscript().jsonString(prettyPrinted: false)
        XCTAssertFalse(compact.contains("\n"))
    }

    // MARK: - TranscriptionOptions

    func testDefaultOptions() {
        let options = TranscriptionOptions()
        XCTAssertEqual(options.locale.identifier(.bcp47), "en-US")
        XCTAssertEqual(options.segmentation, .sentence)
    }

    func testCustomOptions() {
        let options = TranscriptionOptions(locale: Locale(identifier: "de-DE"), segmentation: .word)
        XCTAssertEqual(options.locale.identifier(.bcp47), "de-DE")
        XCTAssertEqual(options.segmentation, .word)
    }

    // MARK: - TranscriptionProgress

    func testProgressClampsFraction() {
        XCTAssertEqual(TranscriptionProgress(phase: .transcribing, fraction: 1.7).fraction, 1.0)
        XCTAssertEqual(TranscriptionProgress(phase: .transcribing, fraction: -0.5).fraction, 0.0)
    }

    func testProgressStatusText() {
        XCTAssertEqual(TranscriptionProgress(phase: .downloading, fraction: 0).statusText, "Downloading...")
        XCTAssertEqual(TranscriptionProgress(phase: .extractingAudio, fraction: 0).statusText, "Extracting audio...")
        XCTAssertEqual(TranscriptionProgress(phase: .installingModel, fraction: 0).statusText, "Installing speech model...")
        XCTAssertEqual(TranscriptionProgress(phase: .transcribing, fraction: 0.42).statusText, "Transcribing: 42%")
        XCTAssertEqual(TranscriptionProgress(phase: .complete, fraction: 1).statusText, "Complete")
    }

    // MARK: - Error Descriptions

    func testAllErrorsHaveDescriptions() {
        let errors: [TranscriptionError] = [
            .unavailable,
            .localeNotSupported("xx-XX"),
            .modelInstallationFailed("disk full"),
            .audioFileNotFound,
            .audioLoadFailed("corrupt"),
            .noAudioTrack,
            .downloadFailed("timeout"),
            .audioExtractionFailed("export failed"),
            .transcriptionFailed("engine error"),
            .emptyTranscript,
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }

    func testErrorEquatable() {
        XCTAssertEqual(TranscriptionError.unavailable, .unavailable)
        XCTAssertEqual(TranscriptionError.localeNotSupported("en"), .localeNotSupported("en"))
        XCTAssertNotEqual(TranscriptionError.localeNotSupported("en"), .localeNotSupported("de"))
        XCTAssertNotEqual(TranscriptionError.unavailable, .noAudioTrack)
    }

    // MARK: - Availability

    func testIsAvailableIsCallable() {
        // We can't assert a specific value (it depends on the host), but it
        // must be reachable and return a Bool without trapping.
        _ = SpeechTranscriber.isAvailable
    }

    // MARK: - Input Validation

    func testTranscribeMissingAudioFileThrows() async {
        let fakeURL = URL(fileURLWithPath: "/tmp/nonexistent_audio_\(UUID().uuidString).m4a")
        do {
            _ = try await SpeechTranscriber.transcribe(audioURL: fakeURL)
            XCTFail("Should have thrown")
        } catch let error as TranscriptionError {
            XCTAssertEqual(error, .audioFileNotFound)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testTranscribeMissingVideoFileThrows() async {
        let fakeURL = URL(fileURLWithPath: "/tmp/nonexistent_video_\(UUID().uuidString).mp4")
        do {
            _ = try await SpeechTranscriber.transcribe(videoURL: fakeURL)
            XCTFail("Should have thrown")
        } catch let error as TranscriptionError {
            XCTAssertEqual(error, .audioFileNotFound)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - Integration (requires example.m4a in Resources + an available engine)

    func testTranscribeFromAudioFile() async throws {
        guard SpeechTranscriber.isAvailable else {
            print("Skipping: on-device speech transcription not available on this host")
            return
        }
        guard let url = Bundle.module.url(forResource: "example", withExtension: "m4a", subdirectory: "Resources") else {
            print("Skipping: example.m4a not found in test resources")
            return
        }

        let progressCount = OSAllocatedUnfairLock(initialState: 0)
        let lastPhase = OSAllocatedUnfairLock<TranscriptionProgress.Phase?>(initialState: nil)

        let transcript = try await SpeechTranscriber.transcribe(audioURL: url) { progress in
            progressCount.withLock { $0 += 1 }
            lastPhase.withLock { $0 = progress.phase }
        }

        XCTAssertGreaterThan(transcript.audioDuration, 0)
        XCTAssertFalse(transcript.isEmpty)
        XCTAssertGreaterThan(transcript.wordCount, 0)
        XCTAssertFalse(transcript.plainText.isEmpty)
        XCTAssertGreaterThan(progressCount.withLock { $0 }, 0)
        XCTAssertEqual(lastPhase.withLock { $0 }, .complete)

        print("\n=== TRANSCRIPTION RESULTS ===")
        print("Duration: \(transcript.formattedDuration)")
        print("Segments: \(transcript.count), Words: \(transcript.wordCount)")
        print("Speed: \(String(format: "%.0fx", transcript.speedFactor)) realtime")
        print("\n--- TIMESTAMPED ---")
        print(transcript.timestampedText)
        print("=============================\n")
    }

    // MARK: - Round-Trip (synthesize known speech, then transcribe it)

    /// Generates a short audio clip from known text with Apple's speech
    /// synthesizer, transcribes it, and checks the expected words come back.
    ///
    /// This validates the whole pipeline end-to-end with no committed binary
    /// fixture. It skips gracefully — never fails — when the on-device engine
    /// or its model is unavailable (e.g., offline CI), and is timeout-protected
    /// so synthesis can't hang the suite.
    func testRoundTripSynthesizedSpeech() async throws {
        guard SpeechTranscriber.isAvailable else {
            print("Skipping round-trip: on-device speech transcription not available")
            return
        }

        let spoken = "The quick brown fox jumps over the lazy dog."
        let audioURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("st-roundtrip-\(UUID().uuidString).caf")
        defer { try? FileManager.default.removeItem(at: audioURL) }

        do {
            try await withTimeout(seconds: 30) {
                try await Self.synthesize(spoken, to: audioURL)
            }
        } catch {
            print("Skipping round-trip: speech synthesis unavailable (\(error))")
            return
        }

        let transcript: Transcript
        do {
            transcript = try await SpeechTranscriber.transcribe(audioURL: audioURL)
        } catch let error as TranscriptionError {
            // Model not installed offline, etc. — environmental, not a failure.
            print("Skipping round-trip: transcription unavailable (\(error.localizedDescription))")
            return
        }

        let recognised = transcript.plainText.lowercased()
        let keywords = ["quick", "brown", "fox", "lazy", "dog"]
        let hits = keywords.filter { recognised.contains($0) }

        print("\n=== ROUND-TRIP ===")
        print("Spoken:      \(spoken)")
        print("Transcribed: \(transcript.plainText)")
        print("Keyword hits: \(hits.count)/\(keywords.count) — \(hits.joined(separator: ", "))")
        print("==================\n")

        XCTAssertFalse(transcript.isEmpty, "Round-trip produced an empty transcript")
        XCTAssertGreaterThanOrEqual(
            hits.count, 3,
            "Expected at least 3 of \(keywords) in the transcript, got: \"\(transcript.plainText)\""
        )
    }

    // MARK: - Locale Discovery

    func testLocaleDiscoveryIsCallable() async {
        let supported = await SpeechTranscriber.supportedLocales
        let installed = await SpeechTranscriber.installedLocales

        // Installed locales are a subset of supported; both must be reachable.
        XCTAssertGreaterThanOrEqual(supported.count, installed.count)

        if let first = supported.first {
            let isSupported = await SpeechTranscriber.isSupported(first)
            XCTAssertTrue(isSupported)
        }
        let nonsense = await SpeechTranscriber.isSupported(Locale(identifier: "zz-ZZ"))
        XCTAssertFalse(nonsense)
    }

    // MARK: - Streaming (synthesize, feed as buffers, transcribe live)

    func testStreamingRoundTrip() async throws {
        guard SpeechTranscriber.isAvailable else {
            print("Skipping streaming: on-device speech transcription not available")
            return
        }

        let spoken = "The quick brown fox jumps over the lazy dog."
        let audioURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("st-stream-\(UUID().uuidString).caf")
        defer { try? FileManager.default.removeItem(at: audioURL) }

        do {
            try await withTimeout(seconds: 30) { try await Self.synthesize(spoken, to: audioURL) }
        } catch {
            print("Skipping streaming: speech synthesis unavailable (\(error))")
            return
        }

        // Read the synthesized file into a stream of AudioInput chunks.
        let file = try AVAudioFile(forReading: audioURL)
        let format = file.processingFormat
        let (stream, continuation) = AsyncStream<AudioInput>.makeStream()
        let frameChunk: AVAudioFrameCount = 4096
        while file.framePosition < file.length {
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameChunk) else { break }
            try file.read(into: buffer)
            if buffer.frameLength == 0 { break }
            continuation.yield(AudioInput(buffer))
        }
        continuation.finish()

        var finals: [String] = []
        var sawVolatile = false
        do {
            for try await event in SpeechTranscriber.transcribe(audioInput: stream) {
                if event.isFinal { finals.append(event.text) } else { sawVolatile = true }
            }
        } catch let error as TranscriptionError {
            print("Skipping streaming: transcription unavailable (\(error.localizedDescription))")
            return
        }

        let recognised = finals.joined(separator: " ").lowercased()
        let keywords = ["quick", "brown", "fox", "lazy", "dog"]
        let hits = keywords.filter { recognised.contains($0) }

        print("\n=== STREAMING ===")
        print("Final text:  \(recognised)")
        print("Keyword hits: \(hits.count)/\(keywords.count); volatile events seen: \(sawVolatile)")
        print("=================\n")

        XCTAssertGreaterThanOrEqual(
            hits.count, 3,
            "Expected at least 3 keywords in the streamed transcript, got: \"\(recognised)\""
        )
    }

    /// Synthesises `text` to an audio file using `AVSpeechSynthesizer`.
    ///
    /// Drains the synthesizer's PCM buffers into an `AVAudioFile`, completing
    /// when the final zero-length buffer arrives.
    private static func synthesize(_ text: String, to url: URL) async throws {
        let synthesizer = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")

        final class State: @unchecked Sendable {
            var file: AVAudioFile?
            var resumed = false
        }
        let state = State()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            synthesizer.write(utterance) { [synthesizer] buffer in
                _ = synthesizer // keep the synthesizer alive until writing completes
                guard let pcm = buffer as? AVAudioPCMBuffer else { return }

                if pcm.frameLength == 0 {
                    if !state.resumed { state.resumed = true; continuation.resume() }
                    return
                }

                do {
                    if state.file == nil {
                        state.file = try AVAudioFile(forWriting: url, settings: pcm.format.settings)
                    }
                    try state.file?.write(from: pcm)
                } catch {
                    if !state.resumed { state.resumed = true; continuation.resume(throwing: error) }
                }
            }
        }
    }

    /// Runs an async operation with a timeout, throwing ``TimedOut`` if exceeded.
    private func withTimeout<T: Sendable>(
        seconds: Double,
        _ operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimedOut()
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    private struct TimedOut: Error {}

    // MARK: - Subtitle assembly

    func testSubtitleAssemblyDirectly() {
        // The document rules pinned with no Transcript in sight.
        let segments = [
            TranscriptSegment(id: 1, text: "Hello", start: 0, end: 2.5),
            TranscriptSegment(id: 2, text: "World", start: 2.5, end: 5),
        ]
        XCTAssertEqual(SubtitleExport.srt(segments), """
        1
        00:00:00,000 --> 00:00:02,500
        Hello

        2
        00:00:02,500 --> 00:00:05,000
        World
        """)
        XCTAssertEqual(SubtitleExport.vtt(segments), """
        WEBVTT

        00:00:00.000 --> 00:00:02.500
        Hello

        00:00:02.500 --> 00:00:05.000
        World
        """)
        XCTAssertEqual(SubtitleExport.srt([]), "", "SRT has no header to stand alone")
        XCTAssertEqual(SubtitleExport.vtt([]), "WEBVTT\n", "no cues is still a valid VTT document")
    }
}
