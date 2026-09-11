// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Pickr",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "Pickr",
            dependencies: ["KeyboardShortcuts"],
            path: "Sources/Pickr",
            resources: [
                .process("Assets.xcassets"),
            ],
            linkerSettings: [
                .linkedFramework("CoreAudio"),
                .linkedFramework("AppIntents"),
            ]
        )
    ]
)
