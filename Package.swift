// swift-tools-version: 6.2
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "swift-llm-client",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "LLMClient", targets: ["LLMClient"]),
        .library(name: "LLMTool", targets: ["LLMTool"]),
        .library(name: "LLMChat", targets: ["LLMChat"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "602.0.0"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.0"),
    ],
    targets: [
        .macro(name: "LLMMacros", dependencies: [
            .product(name: "SwiftSyntax", package: "swift-syntax"),
            .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
        ]),
        .target(name: "LLMClient", dependencies: ["LLMMacros"]),
        .target(name: "LLMTool", dependencies: ["LLMClient"]),
        .target(name: "LLMChat", dependencies: ["LLMClient"]),
        // Tests
        .testTarget(name: "LLMClientTests", dependencies: ["LLMClient"]),
        .testTarget(name: "LLMToolTests", dependencies: ["LLMTool", "LLMClient"]),
        .testTarget(name: "LLMChatTests", dependencies: ["LLMChat", "LLMClient"]),
        .testTarget(name: "LLMMacrosTests", dependencies: [
            "LLMMacros", "LLMClient",
            .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
        ]),
    ]
)
