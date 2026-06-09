//
//  LiveTranscriptionEvent.swift
//  SpeechTranscriber
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A single update emitted during live (streaming) transcription.
///
/// As audio streams in, the engine emits a sequence of events. **Volatile**
/// events (``isFinal`` is `false`) are best-guess interim text that may change
/// as more audio arrives — ideal for showing live, updating captions. A
/// **final** event (``isFinal`` is `true`) is stable and will not change.
///
/// ```swift
/// for try await event in SpeechTranscriber.transcribe(audioInput: stream) {
///     if event.isFinal {
///         finalisedText += event.text + " "
///     } else {
///         liveCaption = event.text   // updates rapidly
///     }
/// }
/// ```
public struct LiveTranscriptionEvent: Sendable {

    /// The recognised text for this update.
    public let text: String

    /// Whether this text is final (`true`) or volatile/interim (`false`).
    ///
    /// Volatile events update as more audio arrives; final events are stable.
    public let isFinal: Bool

    /// The start time of this update in seconds, when timing is available.
    public let start: TimeInterval?

    /// The end time of this update in seconds, when timing is available.
    public let end: TimeInterval?

    /// Creates a live transcription event.
    public init(text: String, isFinal: Bool, start: TimeInterval?, end: TimeInterval?) {
        self.text = text
        self.isFinal = isFinal
        self.start = start
        self.end = end
    }
}
