//
//  DiarizerAudioLoader.swift
//  Diarizer
//
//  Created by David Sherlock on 2026.
//

@preconcurrency import AVFoundation
import Foundation

/// Loads an audio file as mono 16 kHz `Float` samples, the format pyannote /
/// SpeakerKit expects.
enum DiarizerAudioLoader {

    static func samples(from url: URL) throws -> [Float] {
        let file: AVAudioFile
        do {
            file = try AVAudioFile(forReading: url)
        } catch {
            throw DiarizationError.audioLoadFailed(error.localizedDescription)
        }

        let sourceFormat = file.processingFormat
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        ) else {
            throw DiarizationError.audioLoadFailed("Could not create 16 kHz mono format.")
        }

        let frameCount = AVAudioFrameCount(file.length)
        guard frameCount > 0,
              let sourceBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: frameCount) else {
            throw DiarizationError.audioLoadFailed("Empty or unreadable audio.")
        }
        do {
            try file.read(into: sourceBuffer)
        } catch {
            throw DiarizationError.audioLoadFailed(error.localizedDescription)
        }

        // Already mono 16 kHz Float — read channel data directly.
        if sourceFormat.sampleRate == 16_000,
           sourceFormat.channelCount == 1,
           sourceFormat.commonFormat == .pcmFormatFloat32,
           let channel = sourceBuffer.floatChannelData {
            return Array(UnsafeBufferPointer(start: channel[0], count: Int(sourceBuffer.frameLength)))
        }

        guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
            throw DiarizationError.audioLoadFailed("Could not create audio converter.")
        }

        let ratio = 16_000.0 / sourceFormat.sampleRate
        let outputCapacity = AVAudioFrameCount(Double(sourceBuffer.frameLength) * ratio) + 16_000
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputCapacity) else {
            throw DiarizationError.audioLoadFailed("Could not allocate output buffer.")
        }

        var consumed = false
        var conversionError: NSError?
        converter.convert(to: outputBuffer, error: &conversionError) { _, statusPointer in
            if consumed {
                statusPointer.pointee = .noDataNow
                return nil
            }
            consumed = true
            statusPointer.pointee = .haveData
            return sourceBuffer
        }
        if let conversionError {
            throw DiarizationError.audioLoadFailed(conversionError.localizedDescription)
        }
        guard let channel = outputBuffer.floatChannelData else {
            throw DiarizationError.audioLoadFailed("Conversion produced no samples.")
        }
        return Array(UnsafeBufferPointer(start: channel[0], count: Int(outputBuffer.frameLength)))
    }
}
