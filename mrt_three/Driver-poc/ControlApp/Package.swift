// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "MRTDriverControl",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "MRTDriverControl",
            targets: ["MRTDriverControl"]),
    ],
    dependencies: [
    ],
    targets: [
        .executableTarget(
            name: "MRTDriverControl",
            dependencies: [],
            path: "Sources"),
        .testTarget(
            name: "MRTDriverControlTests",
            dependencies: ["MRTDriverControl"]),
    ]
)
