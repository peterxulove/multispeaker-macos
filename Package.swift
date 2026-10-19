// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MultiSpeaker",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MultiSpeaker",
            path: "Sources/MultiSpeaker"
        )
    ]
)
