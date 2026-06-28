# ``LLMAgentStep``

エージェントループのステップ実行プロトコルとストリーミングイベント定義。

## Overview

`LLMAgentStep` は `LLMTool` の `ToolCallableClient` を拡張し、エージェントループの
1 ステップを実行・ストリーミングするためのプロトコル `AgentCapableClient` を定義します。

**AgentCapableClient**: このプロトコルを採用したプロバイダー実装は `executeAgentStep` と
`streamAgentStep` を通じてエージェントループの単一ステップを実行します。
ループ制御・ツール実行・履歴管理はエージェントランタイム（`swift-llm-agent` 等）が担い、
このモジュールは純粋なステップ実行レイヤーに留まります。

**StreamingAgentEvent**: ストリーミング実行では `AsyncThrowingStream<StreamingAgentEvent, Error>` が
返されます。`.delta(StreamDelta)` で thinking やテキストの差分をリアルタイムに受け取り、
`.completed(LLMResponse)` でステップ完了時の完全なレスポンスを受け取ります。

```swift
import LLMAgentStep
import LLMTool

// ストリーミングエージェントステップの実行例
let stream = client.streamAgentStep(
    messages: messages,
    model: .claude(.sonnet),
    systemPrompt: systemPrompt,
    tools: tools,
    toolChoice: nil,
    responseSchema: nil,
    thinkingMode: .disabled,
    reasoningEffort: nil,
    maxTokens: nil,
    cachePolicy: .auto
)

for try await event in stream {
    switch event {
    case .delta(let delta):
        // thinking / テキスト差分をリアルタイムに表示
        print(delta.text ?? "")
    case .completed(let response):
        // ステップ完了 — ツール呼び出しの有無を確認してループを継続するか判断
        handleResponse(response)
    }
}
```

デフォルト実装として、`streamAgentStep` は `executeAgentStep` を内部で呼び出す
シム実装が提供されます。ストリーミングをネイティブに対応していないプロバイダーは
このデフォルトをそのまま使用できます。

## Topics

### エージェントステップ

- ``AgentCapableClient``
- ``StreamingAgentEvent``
