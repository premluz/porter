// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ConversationCore",
    platforms: [.macOS(.v26), .iOS(.v26)],
    products: [
        .library(name: "ConversationCore", targets: ["ConversationCore"]),
        .library(name: "PorterStore", targets: ["PorterStore"]),
        .library(name: "PorterPanelModel", targets: ["PorterPanelModel"]),
    ],
    targets: [
        .target(name: "ConversationCore"),
        .testTarget(name: "ConversationCoreTests", dependencies: ["ConversationCore"]),
        .target(name: "PorterStore", dependencies: ["ConversationCore"]),
        .testTarget(name: "PorterStoreTests", dependencies: ["PorterStore", "ConversationCore"]),
        .target(name: "PorterPanelModel", dependencies: ["ConversationCore", "PorterStore"]),
        .testTarget(name: "PorterPanelModelTests", dependencies: ["PorterPanelModel", "PorterStore", "ConversationCore"]),
    ]
)
