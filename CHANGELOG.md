# 変更履歴

このプロジェクトの全ての重要な変更はこのファイルに記録されます。

フォーマットは [Keep a Changelog](https://keepachangelog.com/ja/1.0.0/) に基づいており、
このプロジェクトは [セマンティックバージョニング](https://semver.org/lang/ja/spec/v2.0.0.html) に準拠しています。

## [未リリース]

なし

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
