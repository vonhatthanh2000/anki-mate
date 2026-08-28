// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AnkiImporter",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "AnkiImporter",
            targets: ["AnkiImporter"]
        )
    ],
    targets: [
        .target(
            name: "TranscriptInsightCore",
            path: "AnkiImporter/TranscriptInsightCore"
        ),
        .executableTarget(
            name: "AnkiImporter",
            dependencies: ["TranscriptInsightCore"],
            path: "AnkiImporter",
            exclude: ["Info.plist", "TranscriptInsightCore"]
        ),
        .executableTarget(
            name: "TranscriptInsightChecks",
            dependencies: ["TranscriptInsightCore"],
            path: "Tests/TranscriptInsightChecks"
        )
    ]
)
