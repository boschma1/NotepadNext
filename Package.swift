// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "NotepadNext",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "NotepadNext",
            path: "Sources/NotepadNext",
            resources: [
                .copy("../../Resources")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
