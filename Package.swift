// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Bitz",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "BitzCore",
            targets: ["BitzCore"]
        )
    ],
    targets: [
        .target(
            name: "BitzCore",
            path: "src"
        ),
        .testTarget(
            name: "BitzTests",
            dependencies: ["BitzCore"],
            path: "Tests/BitzTests"
        )
    ]
)
