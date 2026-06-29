# ``LLMClient``

Anthropic Claude・OpenAI GPT・Google Gemini などを統一 API で扱う、swift-llm-client パッケージのアンブレラモジュール。

## Overview

`swift-llm-client` は 9 つのモジュールで構成されるプロバイダー非依存 LLM クライアント。
アプリ・エージェント・マルチモーダルワークフローを問わず、プロバイダーを切り替えても呼び出しコードは変わらない設計。

**基盤プリミティブ** は `LLMCore` に集約される。メッセージ型 `LLMMessage`、
マルチモーダルコンテンツ (`ImageContent`, `AudioContent`, `VideoContent`, `DocumentContent`)、
モデルプロファイル `ModelProfile`、トークン使用量 `TokenUsage`、コスト計算 `CostCalculator` など
すべてのモジュールが依存するプリミティブはここに定義される。
`LLMClient`（このモジュール）は `LLMCore` の上位に位置し、構造化出力マクロ・プロンプト DSL・
`StructuredLLMClient` プロトコルを提供する。

**ツール呼び出しとエージェント** は 2 層に分かれる。`LLMTool` が `@Tool` マクロと
Result Builder 構文の `ToolSet`・`ToolCallableClient` でシングルショットの Function Calling を担い、
`LLMAgentStep` がエージェントループプロトコル `AgentCapableClient` と
ストリーミングイベント `StreamingAgentEvent` で自動ループを担う。

**マルチターン会話** は `LLMChat` が提供する。`ChatCapableClient` の `chat(messages:model:)` は
構造化出力に加えて履歴継続用の `assistantMessage` を `ChatResponse` にまとめて返す。
状態管理には Actor ベースの `ConversationHistory` を使う。

**メディアとプロバイダー互換性** は `LLMMediaKit` と `LLMProviderCompat` が担う。
`LLMMediaKit` は AI 生成メディア (`GeneratedImage`, `GeneratedAudio`) をプラットフォームネイティブ型
(`UIImage`, `NSImage`, `AVAudioPlayer`) に変換する拡張を追加する。
`LLMProviderCompat` は `MediaCompatibility` と `ProviderType` でプロバイダーごとのメディア対応状況を検査する。

**コンテキスト監視** は `LLMContext` が担う。`AgentContextTracker` は host・サブエージェントごとの
コンテキストウィンドウ占有をリアルタイムで集計し、`SegmentBreakdownEngine` で
システムプロンプト・ツール定義・メッセージ履歴のカテゴリ別内訳をオンデマンドに取得できる。

**後方互換** として `LLMDynamicStructured` が存在する。このモジュールは `LLMClient` を再エクスポートしており、
以前の参照を壊さずに移行できる。

---

このモジュール (`LLMClient`) が直接提供する主な機能は次の 3 つ。

**構造化出力**: `@Structured` マクロを型に付与するだけで、JSON Schema の推論・プロンプト注入・
レスポンスのパースを自動的に処理する。

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
構造的に組み立てられる。

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
組み込める。上位レイヤーは `StructuredLLMClient` / `ToolCallableClient` を使い、
プロバイダーを切り替えても呼び出しコードは変わらない。

## Topics

### 基本

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
