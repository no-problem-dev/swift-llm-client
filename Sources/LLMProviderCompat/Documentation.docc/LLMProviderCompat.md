# ``LLMProviderCompat``

プロバイダーごとのメディア対応状況を検査するユーティリティ層。

## Overview

`LLMProviderCompat` はプロバイダー実装が特定のメディア種別・フォーマットをサポートするかどうかを
実行時に問い合わせるためのユーティリティを提供します。

**プロバイダー機能宣言**: `ProviderCapabilities` プロトコルはサポートするモダリティ（テキスト・画像入力・
画像生成など）を宣言するインターフェースです。`ProviderType` がビルトインのプロバイダー識別子を定義し、
各ケースがデフォルトの機能セットを持ちます。

**互換性チェック**: `MediaCompatibility` の静的メソッドはリクエストに含まれるメディアが
指定プロバイダーで送信可能かどうかを事前検証します。非対応の組み合わせを早期に検知することで、
実際の API 呼び出しで起きる不明瞭なエラーを防ぎます。

```swift
import LLMProviderCompat

// プロバイダーが動画入力に対応しているか確認する例
let compatible = MediaCompatibility.isSupported(
    modality: .videoInput,
    for: ProviderType.anthropic
)
if !compatible {
    throw ProviderCompatibilityError.unsupportedModality(.videoInput, provider: .anthropic)
}
```

## Topics

### プロバイダー機能

- ``ProviderCapabilities``
- ``ProviderType``

### 互換性チェック

- ``MediaCompatibility``
- ``ProviderCompatibilityError``
