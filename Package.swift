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
        ),
        .executable(
            name: "Bitz",
            targets: ["Bitz"]
        )
    ],
    targets: [
        .target(
            name: "BitzCore",
            path: "src",
            exclude: ["Executable"]
        ),
        .executableTarget(
            name: "Bitz",
            dependencies: ["BitzCore"],
            path: "src/Executable"
        ),
        .testTarget(
            name: "BitzTests",
            dependencies: ["BitzCore"],
            path: "Tests/BitzTests"
        )
    ]
)
