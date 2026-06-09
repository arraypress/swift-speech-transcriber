# Swift Speech Transcriber

Transcribe audio and video to timestamped text entirely on-device. No network access, no third-party dependencies, no API keys, no per-minute cost — pure Apple `SpeechAnalyzer`.

Built on Apple's `SpeechAnalyzer` / `SpeechTranscriber` (macOS 26 / iOS 26). Accepts a local audio file, a remote audio URL, or a local/remote video URL, and returns a structured transcript with sentence-level timestamps and SRT/VTT/JSON export.

## Features

- 🎯 **Simple API** — transcribe with a single async call
- 🎙️ **On-device** — Apple `SpeechAnalyzer`, completely free, no data leaves the machine
- 🧠 **Two engines, one API** — Apple `SpeechAnalyzer` (fastest, zero-dependency) **or** Whisper via WhisperKit (accuracy + 100 languages); both return the same `Transcript`
- 🔗 **Audio or video** — local files or remote URLs; video audio tracks are extracted automatically
- 🔴 **Live streaming** — feed microphone or system audio and get interim + final captions in real time
- ⏱️ **Timestamped segments** — sentence-level (or word-level) timing for every line
- 💬 **Subtitle export** — SubRip (`.srt`) and WebVTT (`.vtt`) out of the box
- 📦 **JSON export** — `snake_case` JSON, great for LLM input or storage
- 🌍 **Locale management** — discover supported/installed languages and pre-download models
- 🎤 **Microphone helper** — built-in `MicrophoneCapture` for live transcription
- 📊 **Progress reporting** — real-time callbacks for UI integration
- 🔒 **Sandbox-friendly** — temp files only, no security-scoped grants required
- 🍎 **Cross-platform** — macOS 26+, iOS 26+
- 🔒 **Zero dependencies (Apple engine)** — the `SpeechTranscriber` product uses only Speech + AVFoundation; WhisperKit is an opt-in second product

## Requirements

- macOS 26.0+ / iOS 26.0+
- Swift 6.2+
- Xcode 26.0+

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/arraypress/swift-speech-transcriber.git", from: "1.0.0")
]
```

The package vends **two library products** — depend on whichever engine(s) you need:

- **`SpeechTranscriber`** — the Apple `SpeechAnalyzer` engine. **Zero dependencies.**
- **`WhisperTranscriber`** — the Whisper engine (pulls in WhisperKit). Returns the same `Transcript` type.

## Usage

### Basic Transcription

```swift
import SpeechTranscriber

// A local audio file
let transcript = try await SpeechTranscriber.transcribe(audioURL: fileURL)

// Plain text dump (great for LLM input)
print(transcript.plainText)

// Timestamped, one segment per line
for segment in transcript.segments {
    print("[\(segment.formattedStart)] \(segment.text)")
}
```

### Whisper Engine (optional)

Same call shape, same `Transcript` out — swap the engine when you want Whisper's
accuracy and 100-language coverage. Models download from Hugging Face on first
use and are cached. Use this as the "engine" toggle in your app's settings.

```swift
import WhisperTranscriber

let transcript = try await WhisperTranscriber.transcribe(
    audioURL: url,
    model: .largeV3Turbo,   // .auto picks per device; .tiny … .largeV3
    language: nil           // nil = auto-detect, or "en", "de", …
)

print(transcript.plainText)
let srt = transcript.srt    // same export helpers as the Apple engine
```

A typical settings-driven dispatch:

```swift
enum Engine { case apple, whisper }

func transcribe(_ url: URL, using engine: Engine) async throws -> Transcript {
    switch engine {
    case .apple:   return try await SpeechTranscriber.transcribe(audioURL: url)
    case .whisper: return try await WhisperTranscriber.transcribe(audioURL: url, model: .largeV3Turbo)
    }
}
```

### From a Remote URL

```swift
// Remote audio — downloaded to a temp file, transcribed, cleaned up
let podcast = try await SpeechTranscriber.transcribe(
    audioURL: URL(string: "https://example.com/episode.mp3")!
)

// A video's audio track — extracted, then transcribed
let clip = try await SpeechTranscriber.transcribe(videoURL: videoURL)
```

### Check Availability

```swift
guard SpeechTranscriber.isAvailable else {
    // Present a fallback — this device/OS can't run the on-device engine
    return
}
```

### Custom Options

```swift
let options = TranscriptionOptions(
    locale: Locale(identifier: "de-DE"),  // any installed speech locale
    segmentation: .sentence               // .sentence (default) or .word
)
let transcript = try await SpeechTranscriber.transcribe(audioURL: url, options: options)
```

### Live Streaming

Feed captured audio (microphone, system audio, or a file read in chunks) and
receive interim (`isFinal == false`) and final captions as they're recognised:

```swift
let mic = try MicrophoneCapture()

for try await event in SpeechTranscriber.transcribe(audioInput: mic.stream()) {
    if event.isFinal {
        transcript += event.text + " "
    } else {
        liveCaption = event.text   // updates rapidly as you speak
    }
}
mic.stop()
```

Any source works — just yield `AudioInput` values into an `AsyncStream`:

```swift
let (stream, continuation) = AsyncStream<AudioInput>.makeStream()
// ...from your own AVAudioEngine tap, ScreenCaptureKit, or file reads...
continuation.yield(AudioInput(pcmBuffer))
continuation.finish()

for try await event in SpeechTranscriber.transcribe(audioInput: stream) { ... }
```

> Microphone access requires `NSMicrophoneUsageDescription` (and, on macOS, the
> audio-input entitlement). The OS prompts on first use.

### Locale Management

Discover supported and installed languages, and pre-download a model so the
first transcription doesn't pay the download cost:

```swift
let supported = await SpeechTranscriber.supportedLocales   // [Locale]
let installed = await SpeechTranscriber.installedLocales

if await SpeechTranscriber.isSupported(locale),
   await !SpeechTranscriber.isInstalled(locale) {
    try await SpeechTranscriber.prepare(locale: locale) { progress in
        print(progress.statusText)
    }
}
```

### Subtitle Export

```swift
let transcript = try await SpeechTranscriber.transcribe(videoURL: videoURL)

try transcript.srt.write(to: srtURL, atomically: true, encoding: .utf8)
try transcript.vtt.write(to: vttURL, atomically: true, encoding: .utf8)
```

### JSON Export

```swift
let transcript = try await SpeechTranscriber.transcribe(audioURL: url)

let json = try transcript.jsonString()       // pretty, snake_case
let data = try transcript.jsonData()          // for APIs / files
let compact = try transcript.jsonString(prettyPrinted: false)
```

### Progress Reporting

```swift
let transcript = try await SpeechTranscriber.transcribe(audioURL: url) { progress in
    print(progress.statusText)               // "Transcribing: 42%"
    progressBar.progress = progress.fraction // 0.0–1.0
}
```

### Error Handling

```swift
do {
    let transcript = try await SpeechTranscriber.transcribe(audioURL: url)
} catch TranscriptionError.unavailable {
    print("On-device transcription requires macOS 26 / iOS 26")
} catch TranscriptionError.noAudioTrack {
    print("That video has no audio")
} catch TranscriptionError.localeNotSupported(let id) {
    print("No speech model available for \(id)")
} catch {
    print("Error: \(error.localizedDescription)")
}
```

## How It Works

```
SpeechTranscriber.transcribe(audioURL:/videoURL:)
  ├─ Fetch       → download remote audio, or extract a video's audio track to .m4a
  ├─ Reserve     → reserve the locale and install its speech model on first use
  ├─ Analyze     → SpeechAnalyzer streams recognized text via AsyncSequence
  ├─ Segment     → NLTokenizer splits text; audioTimeRange gives per-segment timing
  └─ Transcript  → segments + plainText + SRT/VTT/JSON
```

All transcription happens on-device. The first run for a locale downloads Apple's
speech model; every run after that is fully offline. Temporary files are written
to the system temporary directory, so the library works inside the App Sandbox
without any security-scoped bookmarks.

## Models

| Property | Type | Description |
|----------|------|-------------|
| `segments` | `[TranscriptSegment]` | Timed segments in chronological order |
| `audioDuration` | `TimeInterval` | Total audio duration in seconds |
| `transcriptionTime` | `TimeInterval` | Wall-clock time spent transcribing |
| `plainText` | `String` | All segment text joined with spaces |
| `timestampedText` | `String` | `"[0:00] Hello everyone"`, one per line |
| `wordCount` | `Int` | Total words across all segments |
| `speedFactor` | `Double` | Transcription speed vs real time (e.g. 30×) |
| `srt` / `vtt` | `String` | SubRip / WebVTT subtitle documents |

## Use Cases

- **Podcasts** — turn an episode URL into a searchable, quotable transcript
- **Interviews** — private, on-device transcription for sensitive audio
- **Subtitles** — batch SRT/VTT for a back-catalogue of videos
- **Meeting recordings** — recorded calls into editable notes
- **Content repurposing** — pull quotes and chapters out of long-form audio

## Testing

```bash
swift test
```

Unit tests cover time formatting, segment and transcript models, SRT/VTT/JSON export, options, progress, error handling, and input validation. The integration test requires an `example.m4a` in the test resources directory and an available on-device engine — it skips gracefully when either is missing.

## License

MIT License — see LICENSE file for details.

## Author

Created by David Sherlock ([ArrayPress](https://github.com/arraypress)) in 2026.
