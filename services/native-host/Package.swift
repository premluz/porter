// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "native-host",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "BridgeTransport", targets: ["BridgeTransport"]),
        .library(name: "NativeSources", targets: ["NativeSources"]),
        .executable(name: "porter-native-host", targets: ["porter-native-host"]),
        .executable(name: "porter-registryd", targets: ["porter-registryd"]),
        .executable(name: "porterctl", targets: ["porterctl"]),
    ],
    dependencies: [
        .package(path: "../../packages/ConversationCore"),
    ],
    targets: [
        .target(name: "BridgeTransport", dependencies: ["ConversationCore"]),
        .target(name: "NativeSources", dependencies: ["ConversationCore"]),
        .testTarget(name: "NativeSourcesTests", dependencies: ["NativeSources", "BridgeTransport", "ConversationCore"]),
        .executableTarget(name: "porter-native-host", dependencies: ["BridgeTransport"]),
        .executableTarget(name: "porter-registryd", dependencies: ["BridgeTransport", "ConversationCore"]),
        .executableTarget(name: "porterctl", dependencies: ["BridgeTransport", "ConversationCore"]),
        .testTarget(
            name: "BridgeTransportTests",
            dependencies: ["BridgeTransport", "ConversationCore", "porter-native-host", "porterctl"]
        ),
    ]
)
