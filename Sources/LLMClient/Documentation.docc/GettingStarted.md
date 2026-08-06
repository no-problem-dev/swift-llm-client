# Getting Started with LLMClient

`LLMClient` を使って、型安全な構造化出力と柔軟なプロンプト DSL を活用する方法を説明する。

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
```

ターゲットの依存に必要なモジュールを追加する。

```swift
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "LLMClient", package: "swift-llm-client"),
        .product(name: "LLMTool",   package: "swift-llm-client"),
    ]
)
```

## Basic Usage

### 1. 構造化出力型を定義する

`@Structured` マクロを使うと、型に `StructuredProtocol` 準拠・`jsonSchema` 静的プロパティが
自動的に合成される。各フィールドには `@StructuredField` で説明と制約を付与する。

```swift
import LLMClient

@Structured("レシピ情報")
struct Recipe {
    @StructuredField("料理名")
    var name: String

    @StructuredField("材料リスト（各材料名と分量）")
    var ingredients: [String]

    @StructuredField("調理時間（分）", .minimum(1), .maximum(300))
    var cookingMinutes: Int

    @StructuredField("難易度", .enum(["easy", "medium", "hard"]))
    var difficulty: String
}
```

### 2. クライアントで生成する

任意のプロバイダー実装（`AnthropicClient`, `OpenAIClient` など）を `StructuredLLMClient` として
受け取り、`generate(input:model:)` を呼び出す。

```swift
// プロバイダー実装は別パッケージ（例: swift-llm-cloud）が提供
let client: any StructuredLLMClient<LLMModel> = AnthropicClient(apiKey: "sk-ant-...")

let recipe: Recipe = try await client.generate(
    input: "簡単なペペロンチーノの作り方を教えて",
    model: .claude(.sonnet)
)

print(recipe.name)            // "ペペロンチーノ"
print(recipe.cookingMinutes)  // 15
```

トークン使用量も取得したい場合は `generateWithUsage(input:model:)` を使う。

```swift
let result: GenerationResult<Recipe> = try await client.generateWithUsage(
    input: "簡単なペペロンチーノの作り方を教えて",
    model: .claude(.sonnet)
)

print(result.result.name)       // "ペペロンチーノ"
print(result.usage.inputTokens) // 入力トークン数
print(result.usage.outputTokens) // 出力トークン数
```

### 3. プロンプト DSL を使う

`SystemPrompt` と `PromptComponent` で構造的なシステムプロンプトを組み立てる。
`render()` メソッドで XML タグ形式に変換される。

```swift
let systemPrompt = SystemPrompt {
    PromptComponent.role("経験豊富な料理研究家")
    PromptComponent.objective("ユーザーのリクエストからレシピ情報を抽出する")
    PromptComponent.constraint("材料の分量は必ず具体的な数値で記載する")
    PromptComponent.example(
        input: "カルボナーラを作りたい",
        output: #"{"name":"カルボナーラ","cookingMinutes":20,"difficulty":"medium"}"#
    )
}

let recipe: Recipe = try await client.generate(
    input: "ビーフシチューの本格レシピ",
    model: .claude(.sonnet),
    systemPrompt: systemPrompt
)
```

### 4. マルチモーダル入力

`LLMInput` を使うと、テキストに画像・音声・動画を組み合わせられる。

```swift
let imageContent = ImageContent.base64(imageData, mediaType: .jpeg)

let input = LLMInput(
    "この画像のレシピを解析してください",
    images: [imageContent]
)

let recipe: Recipe = try await client.generate(
    input: input,
    model: .gemini(.flash36)  // 画像対応モデルを指定
)
```

### 5. 会話履歴を使った生成

複数ターンの会話では `messages` オーバーロードを使う。

```swift
var messages: [LLMMessage] = []

// 最初のターン
messages.append(.user("東京のおすすめ観光スポットを3つ教えて"))
let firstRecipe: CityTips = try await client.generate(
    messages: messages,
    model: .claude(.sonnet)
)

// 会話を継続
messages.append(.assistant(firstRecipe.description))
messages.append(.user("その中で子ども連れに最適な場所はどこ？"))
let followUp: CityTips = try await client.generate(
    messages: messages,
    model: .claude(.sonnet)
)
```

## Next Steps

ツールコール（Function Calling）やエージェントループを使う場合は、
`LLMTool` モジュールの `Tool` プロトコルと `ToolSet` を参照のこと。
