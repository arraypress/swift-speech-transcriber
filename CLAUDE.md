# CLAUDE.md — swift-speech-transcriber

Speech-to-text for macOS/iOS: four engines behind one shared result type. macOS 26 / iOS 26. Tagged **v1.1.0** — note **Parakeet landed after that tag and hasn't been re-tagged**.

Sibling libraries: `swift-tts` (the TTS side), `swift-llm` (LLMKit).

## Build & test
```bash
swift build
swift test
```

## The four products

All return the same `Transcript` (segments, SRT/VTT/JSON export, `plainText`/`timestampedText`/`wordCount`/`speedFactor`) and the same `LiveTranscriptionEvent` (volatile/final), so engines are swappable at the call site.

| Product | Engine | Runtime | Batch | Live | Role |
|---|---|---|---|---|---|
| `SpeechTranscriber` | Apple SpeechAnalyzer | ANE | ✅ | ✅ | **The default.** Zero deps, instant, locale discovery, `MicrophoneCapture` |
| `WhisperTranscriber` | WhisperKit | GPU | ✅ | ✅ | **Accuracy tier.** `WhisperModel` tiny…largeV3Turbo, plus `translate` |
| `ParakeetTranscriber` | FluidAudio (NVIDIA Parakeet) | ANE | ✅ | ✅ | Fast, but **accent-weak** — niche only (see below) |
| `Diarizer` | SpeakerKit (pyannote) | — | ✅ | — | `diarize(transcript, audioURL:)` → speaker labels. File-only |

Deps: `argmaxinc/argmax-oss-swift` 1.0.0, `FluidInference/FluidAudio` from 0.9.1 (resolves 0.15.2).

## ⚠️ Accent finding — don't make Parakeet the default

Tested on a **Scottish accent** (2026-06-10):

- **Parakeet — poor.** US-English/LibriSpeech-skewed training makes it fragile on strong regional accents. Fast but wrong.
- **Apple SpeechAnalyzer — good.** Close to Wispr Flow. This is why it's the default.
- **Whisper Large v3 Turbo — the accent tier.** Trained on 680k hours of diverse accented audio; the strongest local bet for non-US accents.

Keep Parakeet only for the "fast, neutral-accent English" niche — it's an isolated target and costs nothing to leave in. Levers that further close the accent gap: **custom vocabulary/dictionary** (biases recognition, big help on mis-hears) and, downstream, telling a cleanup LLM the speaker's accent.

## Gotchas

- **`TranscriptionProgress` name clash.** WhisperKit exports its own `TranscriptionProgress` that collides with ours. Keep `import WhisperKit` isolated to a single file and use the `EngineProgress` alias (already done — don't undo it by adding the import elsewhere).
- **Whisper live flicker (fixed 2026-06-10).** WhisperKit's `currentText` becomes the placeholder `"Waiting for speech..."` and resets every cycle, so captions appeared then cleared. Volatile captions now read `unconfirmedSegments` instead. Don't switch back to `currentText`.
- **Whisper first-run silent hang (fixed).** Model download is now split from load via `WhisperKit.download` + `onModelProgress`, so first run reports progress instead of appearing frozen.
- **Apple live** is responsive; only the first-run model warm-up is slow. That's expected, not a bug.
- **Parakeet live is compile-verified only** — never runtime-tested (needs a mic plus a model download). Treat it as unproven.

## Parakeet API notes (non-obvious)

- **Batch:** `AsrModels.downloadAndLoad(version:progressHandler:)` → `AsrManager().loadModels(_:)` → `manager.transcribe(url, decoderState: &TdtDecoderState(), language: Language?)` → `ASRResult`. Models `.englishV2` (~600 MB) / `.multilingualV3` (~25 EU languages, ~650 MB).
- **Live:** `transcribeLive(model: ParakeetStreamModel)` via `StreamingModelVariant.createManager()` → `StreamingEouAsrManager`. `ParakeetStreamModel` is `.englishLowLatency` (160 ms) / `.englishBalanced` (320 ms, default) / `.multilingual` (1120 ms). **These are separate, smaller streaming models — not the batch v2/v3 ones.**
- Streaming partials are **cumulative** (decoded from `accumulatedTokenIds`, cleared only on `finish`), so Parakeet has no Whisper-style disappearing-text problem.
- `loadModels()` has **no** download-progress callback — only a coarse 0→1.
- Batch segmentation uses canonical-text sentence splitting with **proportional** timestamps. The text is exact; token-accurate segmentation is still a TODO.

## Planned 5th engine — Qwen3-ASR (not built)

MLX-based multilingual ASR with code-switching, via `soniqo/speech-swift` (community quants: `aufklarer/Qwen3-ASR-0.6B-MLX-4bit` ~600 MB, `…1.7B-MLX-8bit` ~1.9 GB). Add later, same isolated-target pattern as Parakeet — justified when code-switching is actually needed, or when MLX is already in the build for something else. It's the heaviest option (MLX static-links ~107 MB), and the author's own note puts it behind Whisper large-v3-turbo for Russian/mixed-English.

Surfaced via a third-party VoiceInk PR, which is **GPLv3 — reimplement, never copy**.

## Conventions
- One engine per target, each isolated so its dependency doesn't leak into the others.
- Commit only when asked; branch off `main` first if needed.
