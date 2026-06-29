# ``LLMCore``

swift-llm-client 全モジュールの基盤プリミティブ。メッセージ・メディア・モデルプロファイル・コスト計算を提供する。

## Overview

`LLMCore` はパッケージ内のすべてのモジュールが依存する共有プリミティブ層。
プロバイダー固有のロジックは含まず、純粋なドメイン型のみを定義する。

**メッセージと会話**: `LLMMessage` は user / assistant / tool ロールのメッセージを表し、
マルチモーダルコンテンツ（画像・音声・動画・ドキュメント）の添付に対応する。
`LLMResponse` は LLM が返したテキスト・ツール呼び出し・トークン使用量をひとつにまとめる。
`ToolResultContent` はツール実行結果（成功・エラー）を型安全に表現する。

**マルチモーダル入力コンテンツ**: `ImageContent`、`AudioContent`、`VideoContent`、`DocumentContent` が
各メディア種別の入力コンテンツ型を提供する。いずれも `MediaSource` を介して Base64・URL・
ファイルパスからのデータ供給をサポートする。

**生成メディア出力**: `GeneratedImage`、`GeneratedAudio`、`GeneratedVideo` が
LLM の生成物を保持する。フォーマット情報は `ImageOutputFormat`、`AudioOutputFormat`、
`VideoOutputFormat` で表現する。プラットフォームネイティブ型（`UIImage` 等）への変換は
`LLMMediaKit` の拡張が提供する。

**モデルプロファイル**: `ModelProfile` はモデルのコンテキストウィンドウサイズ・最大出力トークン・
サポートモダリティ・推論速度・ツール呼び出しサポートレベルを記述する。
`Modality`、`InferenceSpeed`、`ToolCallSupport`、`LanguageSupport` などの列挙型で
プロバイダー横断の比較が可能。

**コスト計算**: `TokenUsage` でトークン消費量を追跡し、`CostCalculator` で金額を算出する。
`Money<USD>`、`Money<JPY>`、`Money<EUR>` の型パラメータ付き通貨型が通貨の混在を防ぐ。
`Pricing` と `PricingTier` でモデルの単価を定義し、`ExchangeRate` で通貨変換を行う。

```swift
import LLMCore

// トークン使用量からコストを計算する例
let usage = TokenUsage(inputTokens: 1000, outputTokens: 500)
let pricing = Pricing.flat(inputPerMTok: 3.0, outputPerMTok: 15.0)
let cost: Money<USD> = CostCalculator.cost(of: usage, with: pricing)
```

**エラー**: `LLMError` はネットワーク・認証・レート制限・コンテキスト超過など
プロバイダー横断の共通エラーケースを定義する。
メディア処理固有のエラーは `MediaError` が担う。

## Topics

### メッセージ

- ``LLMMessage``
- ``LLMResponse``
- ``LLMError``
- ``ToolResultContent``

### マルチモーダル入力

- ``ImageContent``
- ``AudioContent``
- ``VideoContent``
- ``DocumentContent``
- ``MediaSource``
- ``MediaContentProtocol``

### メディア MIME タイプ

- ``ImageMediaType``
- ``AudioMediaType``
- ``VideoMediaType``
- ``DocumentMediaType``
- ``MediaType``
- ``MediaError``

### 生成メディア出力

- ``GeneratedImage``
- ``GeneratedAudio``
- ``GeneratedVideo``
- ``GeneratedMediaProtocol``
- ``ImageOutputFormat``
- ``AudioOutputFormat``
- ``VideoOutputFormat``
- ``OutputMediaFormat``

### モデルプロファイル

- ``ModelProfile``
- ``Modality``
- ``InferenceSpeed``
- ``ToolCallSupport``
- ``LanguageSupport``
- ``SupportLevel``
- ``YearMonth``

### トークン使用量とコスト

- ``TokenUsage``
- ``CacheTier``
- ``ContextOccupancy``
- ``CostCalculator``
- ``Money``
- ``CurrencyProtocol``
- ``USD``
- ``JPY``
- ``EUR``
- ``Pricing``
- ``PricingTier``
- ``ExchangeRate``

### ストリーミングユーティリティ

- ``makeCancellableStream(_:)``
