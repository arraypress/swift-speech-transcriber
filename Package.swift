// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SpeechTranscriber",
    platforms: [
        .macOS(.v26),
        .iOS(.v26)
    ],
    products: [
        // Apple SpeechAnalyzer engine — zero external dependencies.
        .library(
            name: "SpeechTranscriber",
            targets: ["SpeechTranscriber"]
        ),
        // Whisper engine (WhisperKit) — same Transcript types, opt-in dependency.
        .library(
            name: "WhisperTranscriber",
            targets: ["WhisperTranscriber"]
        ),
        // Speaker diarization (SpeakerKit / pyannote) — labels who spoke when.
        .library(
            name: "Diarizer",
            targets: ["Diarizer"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/argmax-oss-swift.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "SpeechTranscriber",
            dependencies: []
        ),
        .target(
            name: "WhisperTranscriber",
            dependencies: [
                "SpeechTranscriber",
                .product(name: "WhisperKit", package: "argmax-oss-swift"),
            ]
        ),
        .target(
            name: "Diarizer",
            dependencies: [
                "SpeechTranscriber",
                .product(name: "SpeakerKit", package: "argmax-oss-swift"),
            ]
        ),
        .testTarget(
            name: "SpeechTranscriberTests",
            dependencies: ["SpeechTranscriber"],
            resources: [
                .copy("Resources")
            ]
        ),
    ]
)
