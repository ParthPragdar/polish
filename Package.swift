// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Polish",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Polish", targets: ["Polish"])],
    targets: [
        .target(name: "PolishCore"),
        .executableTarget(name: "Polish", dependencies: ["PolishCore"]),
        .testTarget(name: "PolishCoreTests", dependencies: ["PolishCore"])
    ]
)
