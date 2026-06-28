# ``LLMMediaKit``

LLM 生成メディアをプラットフォームネイティブ型へ変換する拡張ライブラリ。

## Overview

`LLMMediaKit` は `LLMCore` が定義する生成メディア型（`GeneratedImage`、`GeneratedAudio`、
`GeneratedVideo`）にプラットフォーム固有の変換プロパティを追加します。
アプリ層でメディアを表示・再生するコードを簡潔に書けるようにするアダプタ層です。

**画像変換** (`GeneratedImage` の拡張): iOS / tvOS / watchOS では `uiImage` プロパティで
`UIImage` を取得でき、macOS では `nsImage` で `NSImage` を返します。
`CoreGraphics` が利用可能な環境では `cgImage` と `imageSize` も使えます。

**音声変換** (`GeneratedAudio` の拡張): `AVFoundation` が使用可能な環境で `audioPlayer` プロパティが
`AVAudioPlayer` インスタンスを返します。そのまま `.play()` を呼び出すだけで再生できます。

```swift
import LLMMediaKit
import LLMCore

// AI 生成画像を UIImage として表示する例（iOS）
let generatedImage: GeneratedImage = try await client.generateImage(
    prompt: "夕暮れの富士山",
    model: .gpt(.dall_e_3)
)

#if canImport(UIKit)
if let uiImage = generatedImage.uiImage {
    imageView.image = uiImage
}
#endif

// AI 生成音声を即座に再生する例
let generatedAudio: GeneratedAudio = try await client.generateAudio(
    text: "こんにちは、今日もよろしくお願いします",
    model: .gpt(.tts_1)
)

#if canImport(AVFoundation)
generatedAudio.audioPlayer?.play()
#endif
```

このモジュールは `#if canImport(...)` ガードで保護されているため、
すべてのプラットフォームにターゲットを追加しても安全です。

## Topics

### 画像変換 (GeneratedImage)

- ``GeneratedImage/uiImage``
- ``GeneratedImage/nsImage``
- ``GeneratedImage/cgImage``
- ``GeneratedImage/imageSize``

### 音声変換 (GeneratedAudio)

- ``GeneratedAudio/audioPlayer``
