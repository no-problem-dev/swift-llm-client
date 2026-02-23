[English](README_EN.md) | 日本語

# LLMClient

プロバイダー非依存の LLM クライアント抽象化 Swift パッケージ

![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017.0+%20%7C%20macOS%2014.0+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

## 特徴

- **プロバイダー非依存** - 統一プロトコルにより任意の LLM プロバイダーを差し替え可能
- **Swift Macro ベースツール定義** - `@LLMTool` マクロで型安全な Function Calling を実現
- **構造化出力** - JSON Schema ベースの動的構造化レスポンス
- **ストリーミング** - AsyncThrowingStream によるリアルタイムトークン出力
- **チャット管理** - メッセージ履歴・コンテキスト管理の統一 API

## インストール

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-llm-client.git", .upToNextMajor(from: "1.0.0"))
]
```

### モジュール構成

用途に応じて必要なモジュールのみをインポートできます：

| モジュール | 用途 |
|-----------|------|
| `LLMClient` | コアプロトコル・型定義（LLMProvider, LLMMessage, LLMResponse 等） |
| `LLMTool` | Swift Macro ベースのツール定義（`@LLMTool`, ToolSet） |
| `LLMChat` | チャットメッセージ管理（履歴・コンテキスト） |
| `LLMDynamicStructured` | 動的 JSON Schema ベースの構造化出力 |

## クイックスタート

### LLM プロバイダーの利用

```swift
import LLMClient

// プロバイダーを使ってストリーミング生成
let provider: any LLMProvider = // 任意のプロバイダー実装
for try await chunk in provider.stream(messages: [
    .user("Swift の async/await について説明して")
]) {
    print(chunk.text, terminator: "")
}
```

### ツール定義

```swift
import LLMTool

@LLMTool("現在の天気を取得する")
struct GetWeather {
    @LLMToolParameter("都市名")
    var city: String

    func execute() async throws -> String {
        // 天気 API を呼び出す
        return "東京: 晴れ 25°C"
    }
}
```

## ドキュメント

詳細なガイドと API リファレンスは DocC ドキュメントを参照してください。

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
- [Issue報告](https://github.com/no-problem-dev/swift-llm-client/issues)
- [ディスカッション](https://github.com/no-problem-dev/swift-llm-client/discussions)
- [リリースプロセス](RELEASE_PROCESS.md)
