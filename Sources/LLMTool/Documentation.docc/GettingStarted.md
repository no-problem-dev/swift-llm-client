# Getting Started with LLMTool

`@Tool` マクロを使って型安全なツール（Function Calling）を定義し、エージェントループと連携する方法を説明する。

## Installation

Swift Package Manager で追加する。

```swift
// Package.swift
dependencies: [
    .package(
        url: "https://github.com/no-problem-dev/swift-llm-client.git",
        from: "3.9.0"
    )
]

// ターゲット依存
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "LLMTool", package: "swift-llm-client"),
    ]
)
```

## Basic Usage

### 1. ツールを定義する

`@Tool` マクロをクラスまたは構造体に付与する。
`@ToolArgument` で LLM に渡す引数を宣言し、`call()` メソッドに実装を書く。

```swift
import LLMTool

@Tool("指定した都市の現在の天気を返します")
struct GetWeather {
    // 設定プロパティ（@ToolArgument なし）はツール引数にならない
    var apiKey: String

    @ToolArgument("都市名（日本語または英語）")
    var city: String

    @ToolArgument("温度単位", .enum(["celsius", "fahrenheit"]))
    var unit: String?

    func call() async throws -> String {
        // 実際の API 呼び出し
        return "\(city): 晴れ、25°C"
    }
}
```

引数のない場合は何も宣言しなくていい。`EmptyArguments` が自動的に使用される。

```swift
@Tool("現在の日時を ISO 8601 形式で返します")
struct GetCurrentTime {
    func call() async throws -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}
```

### 2. ToolSet を組み立てる

Result Builder 構文でツールをまとめる。条件分岐やループも使える。

```swift
let tools = ToolSet {
    GetWeather(apiKey: weatherApiKey)
    GetCurrentTime()

    if userHasPremium {
        AdvancedSearchTool(index: searchIndex)
    }

    for tool in dynamicTools {
        tool
    }
}
```

### 3. ツール呼び出しを計画・実行する

`ToolCallableClient` の `planToolCalls(prompt:model:tools:)` を使い、LLM にツール選択を
させる。このメソッドは実際のツール実行は行わず、計画（`ToolCallResponse`）のみを返す。

```swift
let plan = try await client.planToolCalls(
    prompt: "東京と大阪の天気を比較して教えて",
    model: .claude(.sonnet),
    tools: tools
)

// LLM が選んだツールを順番に実行する
for call in plan.toolCalls {
    print("呼び出し: \(call.name)")

    let result = try await tools.execute(toolNamed: call.name, with: call.arguments)
    print("結果: \(result.stringValue)")
}
```

### 4. 引数を型安全にデコードする

`ToolCall.decodeArguments(as:)` で引数を任意の `Decodable` 型にデコードできる。

```swift
for call in plan.toolCalls where call.name == "get_weather" {
    // @ToolArgument で定義した引数が自動生成された構造体としてデコードされる
    struct WeatherArgs: Decodable {
        let city: String
        let unit: String?
    }
    let args = try call.decodeArguments(as: WeatherArgs.self)
    print("都市: \(args.city)")
}
```

`StructuredValue` を使ったキーアクセスも可能。

```swift
let args = try call.argumentsJSON()
if let city = args.string("city") {
    print("都市: \(city)")
}
```

### 5. 会話履歴付きのツール呼び出し

会話が続くケースでは `planToolCalls(messages:model:tools:)` を使う。

```swift
var messages: [LLMMessage] = [
    .user("今の東京の気温は？"),
]

// ターン 1: LLM がツールを計画
let plan = try await client.planToolCalls(
    messages: messages,
    model: .claude(.sonnet),
    tools: tools
)

// ツール結果を収集し、履歴に追加
var toolResults: [(toolCallId: String, name: String, content: ToolResultContent)] = []
for call in plan.toolCalls {
    let result = try await tools.execute(toolNamed: call.name, with: call.arguments)
    toolResults.append((toolCallId: call.id, name: call.name, content: .success(result.stringValue)))
}

// アシスタントのツール計画 + ツール実行結果を履歴に追加し、次ターンへ
messages.append(.toolUses(plan.toolCalls.map { (id: $0.id, name: $0.name, input: $0.arguments) }))
messages.append(.toolResults(toolResults))
```

## Next Steps

エージェントループ（自動的にツール実行→LLM 応答をループする）には
`LLMAgentStep` モジュールの `AgentCapableClient` を参照のこと。
