// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "Tini",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(name: "Tini", path: "Sources/Tini", swiftSettings: [.swiftLanguageMode(.v5)])
    ]
)
