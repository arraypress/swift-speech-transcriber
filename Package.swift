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
        .library(
            name: "SpeechTranscriber",
            targets: ["SpeechTranscriber"]
        ),
    ],
    targets: [
        .target(
            name: "SpeechTranscriber",
            dependencies: []
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
