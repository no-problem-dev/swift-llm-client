# ``LLMClient``

プロバイダー非依存の LLM クライアント抽象化レイヤー。構造化出力・プロンプト DSL・スキーマ定義を提供します。

## Overview

`LLMClient` は、Anthropic Claude、OpenAI GPT、Google Gemini など複数の LLM プロバイダーを
統一プロトコルで扱えるようにするコアライブラリです。

主な機能は次の 3 つです。

**構造化出力**: `@Structured` マクロを型に付与するだけで、JSON Schema の推論・プロンプト注入・
レスポンスのパースを自動的に処理します。

```swift
@Structured("タスク情報")
struct TaskInfo {
    @StructuredField("タイトル")
    var title: String

    @StructuredField("優先度", .enum(["low", "medium", "high"]))
    var priority: String

    @StructuredField("期日（ISO 8601）", .format(.date))
    var dueDate: String?
}

// プロバイダー実装を介して呼び出す
let task: TaskInfo = try await client.generate(
    input: "明日の朝9時までに議事録を書く（優先度: 高）",
    model: .claude(.sonnet)
)
```

**プロンプト DSL**: `SystemPrompt` と `PromptComponent` を使い、役割・目的・制約・例示を
構造的に組み立てられます。

```swift
let prompt = SystemPrompt {
    PromptComponent.role("データ分析の専門家")
    PromptComponent.objective("テキストから構造化情報を抽出する")
    PromptComponent.constraint("明示されていない情報は推測しない")
    PromptComponent.example(
        input: "田中さん（42）は大阪に在住",
        output: #"{"name":"田中","age":42,"city":"大阪"}"#
    )
}
```

**プロバイダー拡張**: `LLMProvider` プロトコルを実装することで、任意のプロバイダーをプラグインとして
組み込めます。上位レイヤーは `StructuredLLMClient` / `ToolCallableClient` を使い、
プロバイダーを切り替えても呼び出しコードは変わりません。

## Topics

### Essentials

- <doc:GettingStarted>

### クライアントプロトコル

- ``StructuredLLMClient``
- ``LLMProvider``
- ``LLMRequest``
- ``GenerationResult``

### メッセージ

- ``LLMMessage``
- ``LLMInput``
- ``LLMInputProtocol``

### レスポンス

- ``LLMResponse``
- ``LLMModel``
- ``LLMError``

### 構造化出力

- ``StructuredProtocol``
- ``JSONSchema``
- ``JSONSchemaType``
- ``JSONSchemaError``
- ``NamedSchema``
- ``FieldConstraint``

### スキーマアダプター

- ``ProviderSchemaAdapter``
- ``SchemaAdaptationResult``
- ``RemovedConstraint``
- ``ConstraintType``
- ``ConstraintValue``

### プロンプト DSL

- ``SystemPrompt``
- ``PromptComponent``
- ``SystemPromptMetadata``
- ``SystemPromptBuilder``

### ストリーミング

- ``StreamDelta``
- ``ThinkingMode``
- ``ReasoningEffort``
- ``PromptCachePolicy``

### マクロ

- ``Structured(_:)``
- ``StructuredField(_:_:)``
- ``StructuredEnum(_:)``
- ``StructuredCase(_:)``

### ユーティリティ

- ``Box``
