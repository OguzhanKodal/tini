// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Tini",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Tini", path: "Sources/Tini")
    ]
)
