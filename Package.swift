// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacOSApp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "MacOSApp",
            targets: ["MacOSApp"])
    ],
    targets: [
        .executableTarget(
            name: "MacOSApp",
            path: "Sources"
        )
    ]
) 