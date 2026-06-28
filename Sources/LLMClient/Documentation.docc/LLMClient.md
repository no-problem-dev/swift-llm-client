# ``LLMClient``

Anthropic Claude・OpenAI GPT・Google Gemini などを統一 API で扱う、swift-llm-client パッケージのアンブレラモジュール。

## Overview

`swift-llm-client` は 9 つのモジュールで構成されるプロバイダー非依存 LLM クライアントです。
アプリ・エージェント・マルチモーダルワークフローを問わず、プロバイダーを切り替えても呼び出しコードが変わらない設計になっています。

**基盤プリミティブ** は `LLMCore` に集約されています。メッセージ型 `LLMMessage`、
マルチモーダルコンテンツ (`ImageContent`, `AudioContent`, `VideoContent`, `DocumentContent`)、
モデルプロファイル `ModelProfile`、トークン使用量 `TokenUsage`、コスト計算 `CostCalculator` など
すべてのモジュールが依存するプリミティブはここに定義されています。
`LLMClient`（このモジュール）は `LLMCore` の上位に位置し、構造化出力マクロ・プロンプト DSL・
`StructuredLLMClient` プロトコルを提供します。

**ツール呼び出しとエージェント** は 2 層に分かれています。`LLMTool` が `@Tool` マクロと
Result Builder 構文の `ToolSet`・`ToolCallableClient` でシングルショットの Function Calling を担い、
`LLMAgentStep` がエージェントループプロトコル `AgentCapableClient` と
ストリーミングイベント `StreamingAgentEvent` で自動ループを担います。

**マルチターン会話** は `LLMChat` が提供します。`ChatCapableClient` の `chat(messages:model:)` は
構造化出力に加えて履歴継続用の `assistantMessage` を `ChatResponse` にまとめて返します。
状態管理には Actor ベースの `ConversationHistory` を使います。

**メディアとプロバイダー互換性** は `LLMMediaKit` と `LLMProviderCompat` が担います。
`LLMMediaKit` は AI 生成メディア (`GeneratedImage`, `GeneratedAudio`) をプラットフォームネイティブ型
(`UIImage`, `NSImage`, `AVAudioPlayer`) に変換する拡張を追加します。
`LLMProviderCompat` は `MediaCompatibility` と `ProviderType` でプロバイダーごとのメディア対応状況を検査します。

**コンテキスト監視** は `LLMContext` が担います。`AgentContextTracker` は host・サブエージェントごとの
コンテキストウィンドウ占有をリアルタイムで集計し、`SegmentBreakdownEngine` で
システムプロンプト・ツール定義・メッセージ履歴のカテゴリ別内訳をオンデマンドに取得できます。

**後方互換** として `LLMDynamicStructured` が存在します。このモジュールは `LLMClient` を再エクスポートしており、
以前の参照を壊さずに移行できます。

---

このモジュール (`LLMClient`) が直接提供する主な機能は次の 3 つです。

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
