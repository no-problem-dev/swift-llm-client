# ``LLMContext``

エージェントのコンテキストウィンドウ占有をリアルタイム追跡・カテゴリ別分析するモニタリング層。

## Overview

`LLMContext` は host およびサブエージェント (A2) ごとのコンテキストウィンドウ使用状況を
集約するためのモジュール。`LLMCore` の `TokenUsage` と `ModelProfile` を基礎とし、
プロバイダー非依存の純粋ドメイン型として設計されている。

**AgentContextTracker**: `@MainActor` クラスで、`agentID` 文字列をキーに各エージェントの
コンテキスト状況を `ContextReport` として保持する。`record(agentID:usage:profile:)` を
API レスポンス受信後に呼ぶだけでライブ占有 (`ContextOccupancy`) が即座に更新される。
SwiftUI の `@Observable` ViewModel からオブザーブしやすいように `@MainActor` に配置されている。

**ContextReport**: `occupancy`（ライブ占有・常時利用可能）と `breakdown`（カテゴリ別内訳・
オンデマンド取得）の 2 種類の情報を持つ。`breakdown` は `SegmentBreakdownEngine` が
`count_tokens` を差分計測して算出するため、UI 表示が必要なときだけ `refreshBreakdown` で取得する。

**SegmentBreakdown**: システムプロンプト (`system`)・ツール定義 (`tools`)・
メッセージ履歴 (`messages`) の各 `ContextSegment` ごとのトークン数を保持する。
`SegmentBreakdownEngine` が計測・キャッシュ（`BreakdownCache`）を担い、
メッセージのみ変化した場合に計測回数を最小化する。

**ContextBarLayout**: UI でコンテキストバーを描画するための補助型。
`ContextBarSegment` と `ContextBarLayout` が占有の内訳を比率ベースのセグメントに変換し、
SwiftUI でプログレスバーとして描画できる形式を提供する。

```swift
import LLMContext
import LLMCore

// エージェントループ内でコンテキスト占有を記録する例
let tracker = AgentContextTracker(counter: tokenCounter)

// API レスポンス受信後に記録
tracker.record(
    agentID: "host",
    usage: response.usage,
    profile: modelProfile
)

// 現在の占有率を確認
if let report = tracker.reports["host"] {
    let occupancy = report.occupancy
    print("使用: \(occupancy.used) / \(occupancy.windowSize ?? 0)")
    print("占有率: \(String(format: "%.1f", (occupancy.usedFraction ?? 0) * 100))%")
}
```

## Topics

### コンテキスト追跡

- ``AgentContextTracker``
- ``ContextReport``

### セグメント分析

- ``ContextSegment``
- ``SegmentBreakdown``
- ``SegmentBreakdownEngine``
- ``ToolGroup``
- ``BreakdownCache``

### UI レイアウト補助

- ``ContextBarLayout``
- ``ContextBarSegment``
