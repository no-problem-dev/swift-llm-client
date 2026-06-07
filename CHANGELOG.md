# 変更履歴

このプロジェクトの全ての重要な変更はこのファイルに記録されます。

フォーマットは [Keep a Changelog](https://keepachangelog.com/ja/1.0.0/) に基づいており、
このプロジェクトは [セマンティックバージョニング](https://semver.org/lang/ja/spec/v2.0.0.html) に準拠しています。

## [未リリース]

なし

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
