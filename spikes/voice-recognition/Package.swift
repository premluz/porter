// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "VoiceRecognitionSpike",
    platforms: [.macOS(.v26)],
    products: [.executable(name: "VoiceSpike", targets: ["VoiceSpike"])],
    targets: [
        .executableTarget(name: "VoiceSpike"),
        .testTarget(name: "VoiceSpikeTests", dependencies: ["VoiceSpike"]),
    ]
)
