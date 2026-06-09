//
//  TimeCode.swift
//  SpeechTranscriber
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Time formatting helpers shared across the transcript models.
///
/// Produces both human-readable clock strings and the millisecond-precise
/// timestamps required by SubRip (`.srt`) and WebVTT (`.vtt`) subtitles.
enum TimeCode {

    /// Formats a time interval as `"M:SS"` or `"H:MM:SS"` for longer durations.
    ///
    /// Negative values are clamped to zero.
    ///
    /// - Parameter seconds: The time in seconds.
    /// - Returns: A clock string such as `"0:00"`, `"1:23"`, or `"1:05:30"`.
    static func clock(_ seconds: Double) -> String {
        let total = Int(max(0, seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    /// Formats a time interval as a SubRip timestamp: `"HH:MM:SS,mmm"`.
    ///
    /// Negative values are clamped to zero.
    ///
    /// - Parameter seconds: The time in seconds.
    /// - Returns: A timestamp such as `"00:01:23,500"`.
    static func srt(_ seconds: Double) -> String {
        let (h, m, s, ms) = components(seconds)
        return String(format: "%02d:%02d:%02d,%03d", h, m, s, ms)
    }

    /// Formats a time interval as a WebVTT timestamp: `"HH:MM:SS.mmm"`.
    ///
    /// Negative values are clamped to zero.
    ///
    /// - Parameter seconds: The time in seconds.
    /// - Returns: A timestamp such as `"00:01:23.500"`.
    static func vtt(_ seconds: Double) -> String {
        let (h, m, s, ms) = components(seconds)
        return String(format: "%02d:%02d:%02d.%03d", h, m, s, ms)
    }

    /// Decomposes a time interval into hours, minutes, seconds, and milliseconds.
    ///
    /// Negative values are clamped to zero.
    private static func components(_ seconds: Double) -> (h: Int, m: Int, s: Int, ms: Int) {
        let totalMilliseconds = Int((max(0, seconds) * 1000).rounded())
        let h = totalMilliseconds / 3_600_000
        let m = (totalMilliseconds % 3_600_000) / 60_000
        let s = (totalMilliseconds % 60_000) / 1000
        let ms = totalMilliseconds % 1000
        return (h, m, s, ms)
    }

}
