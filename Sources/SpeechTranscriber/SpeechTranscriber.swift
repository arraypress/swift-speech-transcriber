//
//  SpeechTranscriber.swift
//  SpeechTranscriber
//
//  Created by David Sherlock on 2026.
//

import AVFoundation
import Foundation
import NaturalLanguage
import Speech

/// Transcribe audio and video to timestamped text entirely on-device.
///
/// `SpeechTranscriber` wraps Apple's `SpeechAnalyzer` / `SpeechTranscriber`
/// (macOS 26 / iOS 26) and returns a structured ``Transcript`` of timed
/// ``TranscriptSegment`` values. It accepts a local audio file, a remote
/// audio URL (downloaded automatically), or a local/remote **video** URL
/// (the audio track is extracted first), then runs recognition without any
/// network access or API keys.
///
/// No third-party dependencies, no API keys, no per-minute cost. The first
/// run for a given locale downloads Apple's speech model on demand; every
/// run after that is fully offline.
///
/// ## Quick Start
///
/// ```swift
/// import SpeechTranscriber
///
/// // A local audio file
/// let transcript = try await SpeechTranscriber.transcribe(audioURL: fileURL)
///
/// // Plain text dump (great for LLM input)
/// print(transcript.plainText)
///
/// // Timestamped, one segment per line
/// for segment in transcript.segments {
///     print("[\(segment.formattedStart)] \(segment.text)")
/// }
/// ```
///
/// ## From a Remote URL
///
/// ```swift
/// // Remote audio (downloaded to a temp file, then transcribed)
/// let podcast = try await SpeechTranscriber.transcribe(
///     audioURL: URL(string: "https://example.com/episode.mp3")!
/// )
///
/// // A video's audio track (extracted, then transcribed)
/// let reel = try await SpeechTranscriber.transcribe(videoURL: videoURL)
/// ```
///
/// ## With Progress
///
/// ```swift
/// let transcript = try await SpeechTranscriber.transcribe(audioURL: url) { progress in
///     print(progress.statusText)          // "Transcribing: 42%"
///     progressBar.progress = progress.fraction
/// }
/// ```
///
/// ## Export
///
/// ```swift
/// let transcript = try await SpeechTranscriber.transcribe(audioURL: url)
/// try transcript.srt.write(to: srtURL, atomically: true, encoding: .utf8)
/// try transcript.vtt.write(to: vttURL, atomically: true, encoding: .utf8)
/// let json = try transcript.jsonString()
/// ```
public enum SpeechTranscriber {

    /// Whether on-device speech transcription is available on this device.
    ///
    /// Returns `false` on hardware or OS versions that cannot run Apple's
    /// `SpeechTranscriber` module. Check this before transcribing if you
    /// want to present a graceful fallback rather than catching
    /// ``TranscriptionError/unavailable``.
    public static var isAvailable: Bool {
        Speech.SpeechTranscriber.isAvailable
    }

    // MARK: - Audio

    /// Transcribes a local audio file or a remote audio URL.
    ///
    /// When `audioURL` is a `file://` URL the file is read in place. When it
    /// is a remote URL the audio is downloaded to a temporary file first and
    /// removed once transcription completes.
    ///
    /// Supported formats are anything `AVAudioFile` can read on the host OS —
    /// mp3, m4a, wav, aiff, caf, flac, and more.
    ///
    /// - Parameters:
    ///   - audioURL: A local file URL or a remote audio URL.
    ///   - options: Transcription configuration. Default is ``TranscriptionOptions()``.
    ///   - progress: An optional callback reporting transcription progress.
    /// - Throws: ``TranscriptionError`` if the audio cannot be fetched, the
    ///   speech model is unavailable, or recognition fails.
    /// - Returns: A ``Transcript`` of timestamped segments.
    public static func transcribe(
        audioURL: URL,
        options: TranscriptionOptions = TranscriptionOptions(),
        progress: (@Sendable (TranscriptionProgress) -> Void)? = nil
    ) async throws -> Transcript {

        let localURL: URL
        let temporaryURL: URL?

        if audioURL.isFileURL {
            guard FileManager.default.fileExists(atPath: audioURL.path) else {
                throw TranscriptionError.audioFileNotFound
            }
            localURL = audioURL
            temporaryURL = nil
        } else {
            progress?(TranscriptionProgress(phase: .downloading, fraction: 0))
            localURL = try await AudioSource.download(audioURL)
            temporaryURL = localURL
        }

        defer {
            if let temporaryURL {
                try? FileManager.default.removeItem(at: temporaryURL)
            }
        }

        return try await run(localAudioFile: localURL, options: options, progress: progress)
    }

    // MARK: - Video

    /// Transcribes the audio track of a local or remote video.
    ///
    /// The audio track is extracted to a temporary `.m4a` file (via
    /// `AVAssetExportSession`), transcribed, and then removed. Works for
    /// progressive video files (mp4, mov) whether on disk or served over HTTP.
    ///
    /// - Parameters:
    ///   - videoURL: A local file URL or a remote video URL.
    ///   - options: Transcription configuration. Default is ``TranscriptionOptions()``.
    ///   - progress: An optional callback reporting transcription progress.
    /// - Throws: ``TranscriptionError`` — in particular ``TranscriptionError/noAudioTrack``
    ///   if the video has no audio, or ``TranscriptionError/audioExtractionFailed(_:)``
    ///   if the export fails.
    /// - Returns: A ``Transcript`` of timestamped segments.
    public static func transcribe(
        videoURL: URL,
        options: TranscriptionOptions = TranscriptionOptions(),
        progress: (@Sendable (TranscriptionProgress) -> Void)? = nil
    ) async throws -> Transcript {

        if videoURL.isFileURL {
            guard FileManager.default.fileExists(atPath: videoURL.path) else {
                throw TranscriptionError.audioFileNotFound
            }
        }

        progress?(TranscriptionProgress(phase: .extractingAudio, fraction: 0))
        let audioURL = try await AudioSource.extractAudio(fromVideo: videoURL)

        defer { try? FileManager.default.removeItem(at: audioURL) }

        return try await run(localAudioFile: audioURL, options: options, progress: progress)
    }

    // MARK: - Engine

    /// Runs the on-device speech pipeline against a local audio file.
    ///
    /// Reserves the requested locale, installs its speech model if needed,
    /// streams recognition results from `SpeechAnalyzer`, and segments each
    /// result into timestamped sentences (or words) using `NLTokenizer` and
    /// the `audioTimeRange` attribute carried on the recognized text.
    ///
    /// - Parameters:
    ///   - url: A local audio file URL that `AVAudioFile` can read.
    ///   - options: Transcription configuration.
    ///   - progress: An optional progress callback.
    /// - Throws: ``TranscriptionError``.
    /// - Returns: A ``Transcript``.
    private static func run(
        localAudioFile url: URL,
        options: TranscriptionOptions,
        progress: (@Sendable (TranscriptionProgress) -> Void)?
    ) async throws -> Transcript {

        // MARK: Availability

        guard isAvailable else {
            throw TranscriptionError.unavailable
        }

        let locale = options.locale

        // MARK: Reserve Locale

        for reserved in await AssetInventory.reservedLocales {
            await AssetInventory.release(reservedLocale: reserved)
        }

        do {
            try await AssetInventory.reserve(locale: locale)
        } catch {
            throw TranscriptionError.localeNotSupported(locale.identifier(.bcp47))
        }

        let transcriber = Speech.SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [],
            attributeOptions: [.audioTimeRange]
        )

        // MARK: Install Model

        let installedLocales = await Speech.SpeechTranscriber.installedLocales
        let isInstalled = installedLocales.contains {
            $0.identifier(.bcp47) == locale.identifier(.bcp47)
        }

        if !isInstalled {
            progress?(TranscriptionProgress(phase: .installingModel, fraction: 0))
            do {
                if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                    try await request.downloadAndInstall()
                }
            } catch {
                throw TranscriptionError.modelInstallationFailed(error.localizedDescription)
            }
        }

        // MARK: Load Audio

        let analyzer = SpeechAnalyzer(modules: [transcriber])

        let audioFile: AVAudioFile
        do {
            audioFile = try AVAudioFile(forReading: url)
        } catch {
            throw TranscriptionError.audioLoadFailed(error.localizedDescription)
        }

        let format = audioFile.processingFormat
        let duration = format.sampleRate > 0
            ? Double(audioFile.length) / format.sampleRate
            : 0

        // MARK: Transcribe

        progress?(TranscriptionProgress(phase: .transcribing, fraction: 0))
        let startedAt = Date()

        do {
            try await analyzer.start(inputAudioFile: audioFile, finishAfterFile: true)
        } catch {
            throw TranscriptionError.transcriptionFailed(error.localizedDescription)
        }

        let unit: NLTokenUnit = options.segmentation == .word ? .word : .sentence
        var segments: [TranscriptSegment] = []
        var segmentId = 0

        do {
            for try await result in transcriber.results {
                segmentId = Self.appendSegments(
                    from: result.text,
                    unit: unit,
                    startingAt: segmentId,
                    into: &segments
                )

                if duration > 0 {
                    let fraction = min(result.resultsFinalizationTime.seconds / duration, 1.0)
                    progress?(TranscriptionProgress(phase: .transcribing, fraction: fraction))
                }
            }
        } catch {
            throw TranscriptionError.transcriptionFailed(error.localizedDescription)
        }

        let transcriptionTime = Date().timeIntervalSince(startedAt)
        progress?(TranscriptionProgress(phase: .complete, fraction: 1))

        guard !segments.isEmpty else {
            throw TranscriptionError.emptyTranscript
        }

        return Transcript(
            segments: segments,
            audioDuration: duration,
            transcriptionTime: transcriptionTime,
            localeIdentifier: locale.identifier(.bcp47)
        )
    }

    /// Splits one recognition result into timestamped segments and appends them.
    ///
    /// Tokenises the recognised text into sentences (or words) with
    /// `NLTokenizer`, then reads the `audioTimeRange` attribute from each
    /// token's runs to derive its start and end time.
    ///
    /// - Parameters:
    ///   - attributed: The recognised, attributed text for one result.
    ///   - unit: The tokenisation unit (`.sentence` or `.word`).
    ///   - startingAt: The last segment id used so far.
    ///   - segments: The accumulating segment array, appended to in place.
    /// - Returns: The new last segment id after appending.
    private static func appendSegments(
        from attributed: AttributedString,
        unit: NLTokenUnit,
        startingAt startingId: Int,
        into segments: inout [TranscriptSegment]
    ) -> Int {

        var segmentId = startingId
        let fullString = String(attributed.characters)

        let tokenizer = NLTokenizer(unit: unit)
        tokenizer.string = fullString

        for tokenRange in tokenizer.tokens(for: fullString.startIndex..<fullString.endIndex) {
            guard
                let lower = AttributedString.Index(tokenRange.lowerBound, within: attributed),
                let upper = AttributedString.Index(tokenRange.upperBound, within: attributed)
            else { continue }

            let slice = attributed[lower..<upper]
            let text = String(slice.characters).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }

            let timeRanges = slice.runs.compactMap { $0.audioTimeRange }
            guard let first = timeRanges.first, let last = timeRanges.last else { continue }

            segmentId += 1
            segments.append(TranscriptSegment(
                id: segmentId,
                text: text,
                start: first.start.seconds,
                end: last.end.seconds
            ))
        }

        return segmentId
    }

}
