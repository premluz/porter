// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PorterMac",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "Porter", targets: ["Porter"]),
    ],
    dependencies: [
        .package(path: "../../packages/ConversationCore"),
        .package(path: "../../services/native-host"),
    ],
    targets: [
        .target(
            name: "PorterMacKit",
            dependencies: [
                .product(name: "ConversationCore", package: "ConversationCore"),
                .product(name: "PorterStore", package: "ConversationCore"),
                .product(name: "PorterPanelModel", package: "ConversationCore"),
                .product(name: "BridgeTransport", package: "native-host"),
                .product(name: "NativeSources", package: "native-host"),
            ]
        ),
        // The live mascot's character spec and animation rules, ported from Rios Brand (PLAN-005); no UI.
        .target(name: "PorterMascot", resources: [.copy("Resources/mascot-spec.v1.json")]),
        .testTarget(name: "PorterMascotTests", dependencies: ["PorterMascot"], resources: [.copy("Fixtures/mascot-parity.v1.json")]),
        .executableTarget(name: "Porter", dependencies: ["PorterMacKit"]),
        .testTarget(
            name: "PorterMacKitTests",
            dependencies: [
                "PorterMacKit",
                .product(name: "ConversationCore", package: "ConversationCore"),
                .product(name: "PorterPanelModel", package: "ConversationCore"),
                .product(name: "PorterStore", package: "ConversationCore"),
            ]
        ),
    ]
)
