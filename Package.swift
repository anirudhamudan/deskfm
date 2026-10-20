// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Spotbar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Spotbar", path: "Sources/Spotbar")
    ]
)
