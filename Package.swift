// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SunScreen",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "SunScreen",
            path: "Sources/SunScreen"
        )
    ]
)
