# 変更履歴

このプロジェクトの全ての重要な変更はこのファイルに記録されます。

フォーマットは [Keep a Changelog](https://keepachangelog.com/ja/1.0.0/) に基づいており、
このプロジェクトは [セマンティックバージョニング](https://semver.org/lang/ja/spec/v2.0.0.html) に準拠しています。

## [未リリース]

なし

## [3.7.0] - 2026-06-14

マルチモーダル基盤の整備。メディア層をヘキサゴナル原則に沿って再設計した。
破壊的変更を含むが運用方針によりマイナーバージョンで提供する。

### 追加
- **`DocumentContent`（PDF/プレーンテキスト入力）**: `MessageContent.document` ケースと
  `DocumentMediaType`（pdf/plainText）、`LLMMessage.user(_:document:)` / `documents` を追加。
  これまで型レベルで表現できなかった PDF 入力に対応。
- **モジュール分割**: `LLMCore`（Foundation のみの純粋ドメイン）/ `LLMProviderCompat`
  （プロバイダ互換性マトリクス）/ `LLMMediaKit`（UIImage 変換等のプラットフォーム機能）を
  独立 product として公開。`LLMClient` は `@_exported import` で従来の `import LLMClient`
  互換を維持。

### 変更（破壊的）
- **ドメイン値型からプロバイダ知識を排除**: `ImageContent.detail`（OpenAI 専用）を削除。
  `ImageContent/AudioContent/VideoContent` の `validate(for:)`、`MediaType.isSupported(by:)`、
  `ProviderType` を `MediaCompatibility`（LLMProviderCompat）へ移設。
- **ドメイン値型からプラットフォーム依存を排除**: `GeneratedImage/Audio/Video` の
  `uiImage`/`nsImage`/`cgImage`/`imageSize`/`audioPlayer`/`downloadData()` を `LLMMediaKit` へ移動。
  コア値型は Foundation のみに。
- `MediaError` から `.notSupportedByProvider` と `validateSupport(_:for:)` を削除
  （`ProviderCompatibilityError` / `MediaCompatibility` へ移行）。`errorDomain` を修正。

### 内部
- God ファイル `LLMProvider.swift` を `LLMResponse`/`LLMMessage`/`LLMError` に分割。
- 旧パッケージ名 `swift-llm-structured-outputs` の残骸を一掃。

## [3.5.0] - 2026-06-08

### 追加
- **ツール引数のスキーマ準拠型強制（coercion）**: `JSONSchema.coerceArguments(_:)` を追加し、
  `ToolSet.execute(toolNamed:with:)` が引数 JSON をツールの `inputSchema` に沿って補正する。
  小型ローカル LLM が数値・真偽値を文字列で出すケース（例: `{"max_results":"10"}`）を、
  スキーマが `integer` / `number` / `boolean` を要求するフィールドに限って変換し、
  厳格な `JSONDecoder` の型不一致エラーを防ぐ。正常な引数・`string` フィールドは不変。
  プロバイダー非依存で全ツールに効く

## [3.4.2] - 2026-06-08

### 変更
- swift-syntax の許容範囲を `from: 602.0.0` から `600.0.0..<604.0.0` に緩和。
  mlx-swift-lm 3.31.3（swift-syntax 600..<601 要求）と同一依存グラフで
  解決できるようにするため（swift-llm-local 2.x のリモート消費に必要）

## [1.0.0] - 2026-02-23

### 追加
- 初回リリース
- **LLMClient** - プロバイダー非依存の LLM クライアントプロトコル
- **LLMTool** - Swift Macro ベースのツール定義
- **LLMChat** - チャットメッセージ管理
- **LLMDynamicStructured** - 動的構造化出力

[未リリース]: https://github.com/no-problem-dev/swift-llm-client/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/no-problem-dev/swift-llm-client/releases/tag/v1.0.0
