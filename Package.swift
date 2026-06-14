// swift-tools-version: 6.2
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "swift-llm-client",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        // 純粋ドメイン層（Foundation のみ・プロバイダ/プラットフォーム非依存）
        .library(name: "LLMCore", targets: ["LLMCore"]),
        .library(name: "LLMProviderCompat", targets: ["LLMProviderCompat"]),
        .library(name: "LLMMediaKit", targets: ["LLMMediaKit"]),
        .library(name: "LLMClient", targets: ["LLMClient"]),
        .library(name: "LLMTool", targets: ["LLMTool"]),
        // エージェントステップ契約（純粋な LLMClient/LLMTool から分離）
        .library(name: "LLMAgentStep", targets: ["LLMAgentStep"]),
        .library(name: "LLMChat", targets: ["LLMChat"]),
        .library(name: "LLMDynamicStructured", targets: ["LLMDynamicStructured"]),
        // コンテキストウィンドウ内訳（差分減算）— 純粋ドメインロジック
        .library(name: "LLMContext", targets: ["LLMContext"]),
    ],
    dependencies: [
        // mlx-swift-lm 3.31.3（swift-syntax 600..<601 要求）と同一グラフで解決できるよう下限を 600 まで許容
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "600.0.0"..<"604.0.0"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.0"),
        .package(url: "https://github.com/no-problem-dev/swift-structured-data.git", from: "1.0.0"),
    ],
    targets: [
        .macro(name: "LLMMacros", dependencies: [
            .product(name: "SwiftSyntax", package: "swift-syntax"),
            .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
        ]),
        // 純粋ドメイン層: Foundation のみに依存（プロバイダ/プラットフォーム非依存）
        .target(name: "LLMCore"),
        // プロバイダ互換性判定: ドメイン型に内向き依存
        .target(name: "LLMProviderCompat", dependencies: ["LLMCore"]),
        // プラットフォーム I/O（UIImage/AVFoundation 変換等）の葉ターゲット
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
        // コンテキスト内訳: TokenCounting port(LLMTool) のみに依存。cloud 非依存の純ロジック。
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
