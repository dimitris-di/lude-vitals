// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "LudeVitals",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "LudeVitals",
            path: "Sources/LudeVitals"
        ),
        .testTarget(
            name: "LudeVitalsTests",
            dependencies: ["LudeVitals"],
            path: "Tests/LudeVitalsTests"
        )
    ]
)
