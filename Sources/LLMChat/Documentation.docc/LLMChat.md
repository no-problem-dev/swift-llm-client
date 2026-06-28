# ``LLMChat``

構造化出力を維持したままマルチターン会話を継続する会話管理レイヤー。

## Overview

`LLMChat` は `LLMClient` の `StructuredLLMClient` を拡張し、マルチターン会話の継続に必要な
要素をひとまとめにした高レベル API を提供します。

**ChatCapableClient**: `StructuredLLMClient` を継承するプロトコルで、`chat(messages:model:)` メソッドを
追加します。`generate` が構造化データのみを返すのに対し、`chat` は `ChatResponse` を返します。
`ChatResponse` には `result`（構造化データ）と `assistantMessage`（次ターンの履歴に追加すべき
`LLMMessage`）の両方が含まれるため、呼び出し側が手動でメッセージを組み立てる必要がありません。

**ConversationHistory**: スレッドセーフな Actor で会話履歴とトークン使用量を管理します。
`append(_:)`・`getMessages()`・`getTotalUsage()` の基本操作に加え、`eventStream` プロパティで
`ConversationEvent` の `AsyncStream` を購読できます。ユーザーメッセージ・アシスタント応答・
ツール呼び出し・エラーそれぞれのイベントタイプが定義されています。

```swift
import LLMChat

// ConversationHistory を使ったマルチターン会話例
let history = ConversationHistory()

// イベント購読（オプション）
Task {
    for await event in history.eventStream {
        if case .usageUpdated(let usage) = event {
            print("累計トークン: \(usage.totalTokens)")
        }
    }
}

// ターン 1
await history.append(.user("Swift の Optional とは何ですか？"))
let response1: ExplainResult = try await client.chat(
    messages: await history.getMessages(),
    model: .claude(.sonnet)
)
await history.append(response1.assistantMessage)

// ターン 2 — 直前の回答を踏まえた追加質問
await history.append(.user("Optional Chaining の具体例を見せてください"))
let response2: ExplainResult = try await client.chat(
    messages: await history.getMessages(),
    model: .claude(.sonnet)
)
await history.append(response2.assistantMessage)

print("会話ターン数: \(await history.turnCount)")
```

## Topics

### クライアントプロトコル

- ``ChatCapableClient``
- ``ChatResponse``

### 会話履歴

- ``ConversationHistory``
- ``ConversationHistoryProtocol``
- ``ConversationEvent``
