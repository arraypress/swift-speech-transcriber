//
//  WhisperText.swift
//  WhisperTranscriber
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Cleans WhisperKit segment text, which embeds special tokens such as
/// `<|startoftranscript|>`, `<|en|>`, `<|transcribe|>`, and `<|0.00|>`.
enum WhisperText {

    /// Strips `<|…|>` special tokens and trims surrounding whitespace.
    static func clean(_ text: String) -> String {
        text
            .replacingOccurrences(of: "<\\|[^|]*\\|>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
