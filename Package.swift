// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Snowfall",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "Snowfall", targets: ["Snowfall"])],
    targets: [
        .target(name: "SnowfallCore"),
        .executableTarget(name: "Snowfall", dependencies: ["SnowfallCore"]),
        .testTarget(name: "SnowfallCoreTests", dependencies: ["SnowfallCore"])
    ]
)
