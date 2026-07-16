// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Cazzy",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Cazzy",
            path: "Sources/Cazzy"
        )
    ]
)
