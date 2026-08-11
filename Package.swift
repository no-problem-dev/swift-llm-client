// swift-tools-version: 6.2
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "swift-llm-client",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        // Pure domain layer: Foundation only, no provider or platform dependency.
        .library(name: "LLMCore", targets: ["LLMCore"]),
        .library(name: "LLMProviderCompat", targets: ["LLMProviderCompat"]),
        .library(name: "LLMMediaKit", targets: ["LLMMediaKit"]),
        .library(name: "LLMClient", targets: ["LLMClient"]),
        .library(name: "LLMTool", targets: ["LLMTool"]),
        // The agent-step contract, kept separate from LLMClient and LLMTool.
        .library(name: "LLMAgentStep", targets: ["LLMAgentStep"]),
        .library(name: "LLMChat", targets: ["LLMChat"]),
        .library(name: "LLMDynamicStructured", targets: ["LLMDynamicStructured"]),
        // Context-window breakdown by differential measurement. Pure domain logic.
        .library(name: "LLMContext", targets: ["LLMContext"]),
    ],
    dependencies: [
        // Lower bound stays at 600 so this resolves in the same graph as mlx-swift-lm 3.31.3,
        // which requires swift-syntax 600..<601.
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "600.0.0"..<"604.0.0"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.0"),
        .package(url: "https://github.com/no-problem-dev/swift-structured-data.git", "1.3.0" ..< "3.0.0"),
    ],
    targets: [
        .macro(name: "LLMMacros", dependencies: [
            .product(name: "SwiftSyntax", package: "swift-syntax"),
            .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
        ]),
        // Pure domain layer: depends on Foundation only.
        .target(name: "LLMCore"),
        // Provider compatibility checks. Depends inward, on the domain types only.
        .target(name: "LLMProviderCompat", dependencies: ["LLMCore"]),
        // Leaf target for platform I/O such as UIImage and AVFoundation conversions.
        .target(name: "LLMMediaKit", dependencies: ["LLMCore"]),
        .target(name: "LLMClient", dependencies: [
            "LLMMacros",
            "LLMCore",
            "LLMProviderCompat",
            .product(name: "StructuredDataCore", package: "swift-structured-data"),
            .product(name: "JSONParsing", package: "swift-structured-data"),
        ]),
        .target(name: "LLMTool", dependencies: [
            "LLMClient",
            .product(name: "StructuredDataCore", package: "swift-structured-data"),
            .product(name: "JSONParsing", package: "swift-structured-data"),
        ]),
        .target(name: "LLMAgentStep", dependencies: ["LLMClient", "LLMTool"]),
        .target(name: "LLMChat", dependencies: ["LLMClient"]),
        .target(name: "LLMDynamicStructured", dependencies: ["LLMClient"]),
        // Context breakdown. Depends only on the TokenCounting port in LLMTool; no network.
        .target(name: "LLMContext", dependencies: ["LLMTool", "LLMClient"]),
        // Tests
        .testTarget(name: "LLMClientTests", dependencies: ["LLMClient"]),
        .testTarget(name: "LLMToolTests", dependencies: [
            "LLMTool", "LLMClient",
            .product(name: "StructuredDataCore", package: "swift-structured-data"),
            .product(name: "JSONParsing", package: "swift-structured-data"),
        ]),
        .testTarget(name: "LLMChatTests", dependencies: ["LLMChat", "LLMClient"]),
        .testTarget(name: "LLMContextTests", dependencies: ["LLMContext", "LLMTool", "LLMClient"]),
        .testTarget(name: "LLMMacrosTests", dependencies: [
            "LLMMacros", "LLMClient",
            .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
        ]),
    ]
)
