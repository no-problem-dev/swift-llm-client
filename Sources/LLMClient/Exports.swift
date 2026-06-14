// swift-llm-client
//
// downstream 互換のための umbrella re-export。
// 既存の `import LLMClient` だけで従来通り全ドメイン型 (LLMCore) と
// プロバイダ互換 API (LLMProviderCompat) が見えるようにする。

@_exported import LLMCore
@_exported import LLMProviderCompat
