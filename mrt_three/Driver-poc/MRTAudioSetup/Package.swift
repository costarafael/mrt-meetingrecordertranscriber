// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MRTAudioSetup",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "MRTAudioSetup", targets: ["MRTAudioSetup"])
    ],
    targets: [
        .executableTarget(
            name: "MRTAudioSetup",
            dependencies: []
        )
    ]
)