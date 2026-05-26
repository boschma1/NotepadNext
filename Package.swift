// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "NotepadMacMac",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "NotepadMacMac",
            path: "Sources/NotepadMacMac",
            resources: [
                .copy("../../Resources")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
