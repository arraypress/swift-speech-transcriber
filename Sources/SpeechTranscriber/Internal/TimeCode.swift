//
//  TimeCode.swift
//  SpeechTranscriber
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Human-readable clock strings for the transcript models.
///
/// Subtitle timestamps are NOT here: they live in swift-subtitle-kit's
/// `TimeCode`, so that this fleet has one answer to what
/// `00:00:59,9996` rounds to rather than three.
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

}
