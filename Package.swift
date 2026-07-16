// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Zycas",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Zycas",
            path: "Sources/Zycas"
        )
    ]
)
