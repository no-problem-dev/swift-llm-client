# ``LLMTool``

Swift Macro ベースの型安全なツール（Function Calling）定義とオーケストレーション。

## Overview

`LLMTool` は、LLM の Function Calling 機能を Swift らしい方法で扱うためのライブラリです。
`@Tool` マクロと `@ToolArgument` マクロを組み合わせることで、型安全なツールを簡潔に定義できます。

```swift
import LLMTool

@Tool("指定した都市の現在の天気を取得します")
struct GetWeather {
    // 設定プロパティ（ツール引数にはならない）
    var apiKey: String

    @ToolArgument("都市名（日本語または英語）")
    var city: String

    @ToolArgument("温度単位", .enum(["celsius", "fahrenheit"]))
    var unit: String?

    func call() async throws -> String {
        // 天気 API を呼び出す実装
        return "\(city): 晴れ、25°C"
    }
}
```

`ToolSet` の Result Builder 構文でツールを束ね、`ToolCallableClient` に渡します。

```swift
let tools = ToolSet {
    GetWeather(apiKey: apiKey)
    SearchWebTool()

    if isPremium {
        AdvancedAnalysisTool()
    }
}

let plan = try await client.planToolCalls(
    prompt: "東京の天気を調べてください",
    model: .claude(.sonnet_4_5),
    tools: tools
)

// 計画されたツール呼び出しを実行
for call in plan.toolCalls {
    let result = try await tools.execute(toolNamed: call.name, with: call.arguments)
    print(result.stringValue)
}
```

ターンを終了させたいツールには `TurnEndingTool` を採用します。エージェントループランタイムが
このマーカープロトコルを検出し、成功結果を受け取った時点でループを打ち切ります。

## Topics

### Essentials

- <doc:GettingStarted>

### ツール定義

- ``Tool``
- ``TurnEndingTool``
- ``ToolDefinition``
- ``EmptyArguments``

### ツールセット

- ``ToolSet``
- ``ToolSetBuilder``
- ``ToolExecutionError``

### ツール呼び出し

- ``ToolCall``
- ``ToolCallResponse``
- ``ToolCallableClient``
- ``ToolChoice``

### ツール実行結果

- ``ToolResult``
- ``ToolResultConvertible``
- ``JSONToolResult``
- ``ToolResponse``
- ``DynamicTool``

### トークン計測

- ``TokenCounting``
- ``ToolAnnotations``

### マクロ

- ``Tool(_:name:)``
- ``ToolArgument(_:_:)``
- ``ToolExclude()``
