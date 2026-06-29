[English](./README.md) | 日本語

# LLMClient

プロバイダー非依存の LLM クライアント抽象化 Swift パッケージ

![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017.0+%20%7C%20macOS%2014.0+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

## 特徴

- **プロバイダー非依存** - 統一プロトコルにより任意の LLM プロバイダーを差し替え可能
- **Swift Macro ベースツール定義** - `@Tool` マクロで型安全な Function Calling を実現
- **構造化出力** - `@Structured` マクロと JSON Schema による型安全な構造化レスポンス
- **ストリーミング** - AsyncThrowingStream によるリアルタイムトークン出力
- **チャット管理** - メッセージ履歴・コンテキスト管理の統一 API

## インストール

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-llm-client.git", .upToNextMajor(from: "3.9.0"))
]
```

### モジュール構成

用途に応じて必要なモジュールのみをインポートできる：

| モジュール | 用途 |
|-----------|------|
| `LLMCore` | 純粋ドメイン層（`LLMMessage`, `LLMResponse`, `TokenUsage`, `ModelProfile` 等） |
| `LLMClient` | クライアントプロトコル・構造化出力・プロンプト DSL（`@Structured`, `SystemPrompt` 等） |
| `LLMTool` | Swift Macro ベースのツール定義（`@Tool`, `@ToolArgument`, `ToolSet`）|
| `LLMAgentStep` | エージェントループ契約（`AgentCapableClient`, `StreamingAgentEvent`） |
| `LLMChat` | 会話継続管理（`ChatCapableClient`, `ConversationHistory`） |
| `LLMContext` | コンテキストウィンドウ内訳・占有トラッキング |
| `LLMMediaKit` | プラットフォーム I/O（`UIImage` / `AVFoundation` 変換等） |

## クイックスタート

### 構造化出力

```swift
import LLMClient

// @Structured マクロで型を定義
@Structured("都市情報")
struct CityInfo {
    @StructuredField("都市名")
    var name: String
    @StructuredField("人口（万人単位）")
    var population: Int
}

// クライアント（プロバイダー実装）で生成
let client: any StructuredLLMClient<LLMModel> = // 任意のプロバイダー実装
let city: CityInfo = try await client.generate(
    input: "東京の人口は約1400万人です",
    model: .claude(.sonnet4_5)
)
print(city.name)       // "東京"
print(city.population) // 1400
```

### ツール定義

```swift
import LLMTool

@Tool("現在の天気を取得する")
struct GetWeather {
    @ToolArgument("都市名")
    var city: String

    func call() async throws -> String {
        // 天気 API を呼び出す
        return "東京: 晴れ 25°C"
    }
}

let tools = ToolSet {
    GetWeather()
}
```

## ドキュメント

詳細なガイドと API リファレンスは DocC ドキュメントを参照のこと。

| ガイド | 内容 |
|-------|------|
| [API Reference](https://no-problem-dev.github.io/swift-llm-client/documentation/llmclient/) | 全パブリック API |

## 要件

- iOS 17.0+ / macOS 14.0+
- Swift 6.2+
- Xcode 16.0+

## ライセンス

MIT License - 詳細は [LICENSE](LICENSE) を参照

## リンク

- [完全なドキュメント](https://no-problem-dev.github.io/swift-llm-client/documentation/llmclient/)
- [Issue 報告](https://github.com/no-problem-dev/swift-llm-client/issues)
- [ディスカッション](https://github.com/no-problem-dev/swift-llm-client/discussions)
- [リリースプロセス](RELEASE_PROCESS.md)
