# ``LLMProviderCompat``

プロバイダーごとのメディア対応状況を検査するユーティリティ層。

## Overview

`LLMProviderCompat` はプロバイダー実装が特定のメディア種別・フォーマットをサポートするかどうかを
実行時に問い合わせるためのユーティリティを提供する。

**プロバイダー機能宣言**: `ProviderCapabilities` プロトコルはサポートするモダリティ（テキスト・画像入力・
画像生成など）を宣言するインターフェース。`ProviderType` がビルトインのプロバイダー識別子を定義し、
各ケースがデフォルトの機能セットを持つ。

**互換性チェック**: `MediaCompatibility` の静的メソッドはリクエストに含まれるメディアが
指定プロバイダーで送信可能かどうかを事前検証する。非対応の組み合わせを早期に検知することで、
実際の API 呼び出しで起きる不明瞭なエラーを防ぐ。

```swift
import LLMProviderCompat

// Anthropic は音声入力非対応、OpenAI は WAV/MP3 のみ対応
let supportsAudio = MediaCompatibility.isSupported(AudioMediaType.mp3, by: .anthropic) // false
let supportsJpeg  = MediaCompatibility.isSupported(ImageMediaType.jpeg, by: .openai)   // true

// Gemini 専用の HEIC を OpenAI に送ろうとすると検証でエラー
let image = ImageContent(source: .base64(mimeType: "image/heic", data: heicData))
do {
    try MediaCompatibility.validate(image, for: .openai)
} catch let error as ProviderCompatibilityError {
    print(error.localizedDescription)
    // "Media type 'image/heic' is not supported by OpenAI"
}
```

## Topics

### プロバイダー機能

- ``ProviderCapabilities``
- ``ProviderType``

### 互換性チェック

- ``MediaCompatibility``
- ``ProviderCompatibilityError``
