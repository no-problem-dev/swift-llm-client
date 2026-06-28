# ``LLMDynamicStructured``

`LLMClient` の後方互換再エクスポートモジュール。

## Overview

`LLMDynamicStructured` はパッケージ再編成以前の参照を維持するための互換シムです。
構造化出力の実装は `LLMClient` へ統合済みであり、`LLMDynamicStructured` は
`@_exported import LLMClient` によってすべての型・マクロ・プロトコルをそのまま再エクスポートします。

既存のターゲットが `LLMDynamicStructured` に依存している場合、コードを変更せずに継続利用できます。
新規コードでは直接 `LLMClient` を依存に追加することを推奨します。

```swift
// 既存コード — 変更不要
import LLMDynamicStructured

@Structured("タスク情報")
struct TaskInfo {
    @StructuredField("タイトル")
    var title: String
}

// 新規コードでの推奨形式
import LLMClient

@Structured("タスク情報")
struct TaskInfo {
    @StructuredField("タイトル")
    var title: String
}
```

## Topics

### 再エクスポート元

- ``StructuredLLMClient``
- ``StructuredProtocol``
- ``JSONSchema``
