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
        .executableTarget(
            name: "AnkiImporter",
            path: "AnkiImporter",
            exclude: ["Info.plist"],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        )
    ]
)
