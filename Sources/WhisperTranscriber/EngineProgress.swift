//
//  EngineProgress.swift
//  WhisperTranscriber
//
//  Created by David Sherlock on 2026.
//

import SpeechTranscriber

/// Internal alias for the shared progress type.
///
/// `WhisperEngine.swift` also imports WhisperKit, whose own `TranscriptionProgress`
/// type would otherwise collide. This file imports only `SpeechTranscriber`, so
/// the name resolves unambiguously here and the engine can refer to it via this
/// alias.
typealias EngineProgress = TranscriptionProgress
