//
//  LocaleSupport.swift
//  SpeechTranscriber
//
//  Created by David Sherlock on 2026.
//

import Foundation
import Speech

public extension SpeechTranscriber {

    /// All locales the on-device transcriber can support.
    ///
    /// A locale being supported does not mean its model is downloaded — check
    /// ``installedLocales`` or ``isInstalled(_:)`` for that, and call
    /// ``prepare(locale:progress:)`` to download it ahead of time.
    ///
    /// ```swift
    /// for locale in await SpeechTranscriber.supportedLocales {
    ///     print(locale.identifier(.bcp47))
    /// }
    /// ```
    static var supportedLocales: [Locale] {
        get async { await Speech.SpeechTranscriber.supportedLocales }
    }

    /// Locales whose on-device model is installed and ready to use offline.
    static var installedLocales: [Locale] {
        get async { await Speech.SpeechTranscriber.installedLocales }
    }

    /// Whether the given locale is supported by the on-device transcriber.
    ///
    /// - Parameter locale: The locale to check.
    /// - Returns: `true` if a model is available (installed or downloadable).
    static func isSupported(_ locale: Locale) async -> Bool {
        let target = locale.identifier(.bcp47)
        return await supportedLocales.contains { $0.identifier(.bcp47) == target }
    }

    /// Whether the given locale's model is already installed for offline use.
    ///
    /// - Parameter locale: The locale to check.
    /// - Returns: `true` if the model is installed.
    static func isInstalled(_ locale: Locale) async -> Bool {
        let target = locale.identifier(.bcp47)
        return await installedLocales.contains { $0.identifier(.bcp47) == target }
    }

    /// Downloads and installs the on-device model for a locale ahead of time.
    ///
    /// Call this from a settings screen or onboarding flow so the first
    /// transcription doesn't pay the download cost. No-op if the model is
    /// already installed.
    ///
    /// ```swift
    /// try await SpeechTranscriber.prepare(locale: Locale(identifier: "de-DE")) { progress in
    ///     print(progress.statusText)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - locale: The locale to prepare.
    ///   - progress: An optional callback for the install phase.
    /// - Throws: ``TranscriptionError/unavailable`` if the engine is unavailable,
    ///   ``TranscriptionError/localeNotSupported(_:)`` if the locale has no model,
    ///   or ``TranscriptionError/modelInstallationFailed(_:)`` on download failure.
    static func prepare(
        locale: Locale,
        progress: (@Sendable (TranscriptionProgress) -> Void)? = nil
    ) async throws {
        guard isAvailable else { throw TranscriptionError.unavailable }
        _ = try await makeTranscriber(locale: locale, volatileResults: false, progress: progress)
    }

}
