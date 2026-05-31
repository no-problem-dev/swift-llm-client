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
        .library(name: "LLMDynamicStructured", targets: ["LLMDynamicStructured"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "602.0.0"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.0"),
        .package(url: "https://github.com/no-problem-dev/swift-structured-data.git", from: "1.0.0"),
    ],
    targets: [
        .macro(name: "LLMMacros", dependencies: [
            .product(name: "SwiftSyntax", package: "swift-syntax"),
            .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
        ]),
        .target(name: "LLMClient", dependencies: [
            "LLMMacros",
            .product(name: "StructuredDataCore", package: "swift-structured-data"),
            .product(name: "JSONParsing", package: "swift-structured-data"),
            .product(name: "XMLCoding", package: "swift-structured-data"),
        ]),
        .target(name: "LLMTool", dependencies: [
            "LLMClient",
            .product(name: "StructuredDataCore", package: "swift-structured-data"),
            .product(name: "JSONParsing", package: "swift-structured-data"),
        ]),
        .target(name: "LLMChat", dependencies: ["LLMClient"]),
        .target(name: "LLMDynamicStructured", dependencies: ["LLMClient"]),
        // Tests
        .testTarget(name: "LLMClientTests", dependencies: ["LLMClient"]),
        .testTarget(name: "LLMToolTests", dependencies: [
            "LLMTool", "LLMClient",
            .product(name: "StructuredDataCore", package: "swift-structured-data"),
            .product(name: "JSONParsing", package: "swift-structured-data"),
        ]),
        .testTarget(name: "LLMChatTests", dependencies: ["LLMChat", "LLMClient"]),
        .testTarget(name: "LLMMacrosTests", dependencies: [
            "LLMMacros", "LLMClient",
            .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
        ]),
    ]
)
