[English](./README.md) | 日本語

# LLMClient

Claude・GPT・Gemini・Grok・Groq・Mistral・DeepSeek を 1 つの Swift API で扱う。モデルやプロバイダを変えても、呼び出し側のコードを書き直さなくていい。

![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017.0+%20%7C%20macOS%2014.0+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

## 特徴

- **プロバイダー非依存** — 呼び出し側のコードを変えずにプロバイダーを差し替えられる
- **構造化出力** — `@Structured` マクロと JSON Schema で、自分の型に直接デコードされる
- **ツール呼び出し** — `@Tool` マクロでツールを宣言する。引数は往復とも型安全
- **ストリーミング** — テキスト・推論・ツール引数の差分を `AsyncThrowingStream` で受け取る
- **トークン計上** — 使用量・プロンプトキャッシュの階層・コスト・コンテキストウィンドウのライブ占有

## クイックスタート

欲しい形を宣言すれば、デコード済みで返ってくる。

```swift
import LLMClient

@Structured("都市情報")
struct CityInfo {
    @StructuredField("都市名")
    var name: String

    @StructuredField("人口（万人単位）")
    var population: Int
}

let city: CityInfo = try await client.generate(
    input: "東京の人口はおよそ 1400 万人です。",
    model: .claude(.sonnet)
)

print(city.name)       // "東京"
print(city.population) // 1400
```

ツールも同じ書き方で宣言し、モデルに呼ばせる。

```swift
import LLMTool

@Tool("指定した都市の現在の天気を取得する")
struct GetWeather {
    @ToolArgument("都市名")
    var city: String

    func call() async throws -> String {
        "\(city): 晴れ 25°C"
    }
}

let plan = try await client.planToolCalls(
    prompt: "東京と大阪の天気を比較して。",
    model: .claude(.sonnet),
    tools: ToolSet { GetWeather() }
)
```

`client` は `StructuredLLMClient` / `ToolCallableClient` に準拠した任意の型。
プロバイダー実装は別パッケージが提供する。

## ドキュメント

API リファレンスとガイドは
[no-problem-dev.github.io/swift-llm-client](https://no-problem-dev.github.io/swift-llm-client/documentation/llmclient/)
にホストされている（英語）。まず **Getting Started** を読み、どのライブラリを import するかは
**Module Layout** で決める。

## インストール

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-llm-client.git", from: "4.0.0")
]
```

必要なライブラリをターゲットの依存に追加する。多くの用途は `LLMClient` と `LLMTool` で足りる。

```swift
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "LLMClient", package: "swift-llm-client"),
        .product(name: "LLMTool", package: "swift-llm-client"),
    ]
)
```

## 要件

- iOS 17.0+ / macOS 14.0+
- Swift 6.2+
- Xcode 16.0+

## ライセンス

MIT License — 詳細は [LICENSE](LICENSE) を参照。
