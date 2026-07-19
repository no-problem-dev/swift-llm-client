# CONSISTENCY — FAMILY_CHARTER からの意図的逸脱

FAMILY_CHARTER の条項に意図的に従わない箇所を、理由付きで宣言する。
宣言済みの逸脱は横断監査（AUDIT_V2 層C の charter judge）で WARN 止まりになる。

## `Tool.toolName` / `Tool.toolDescription` は `name` / `description` に改名しない

**条項**: API イディオム（Swift API Design Guidelines「Omit needless words」— 型名を反復するプレフィックスを避ける）

**逸脱内容**: `Tool` プロトコルの要件を `toolName` / `toolDescription` のまま維持する。2026-06-27 の質的監査は `name` / `description` への改名を勧告したが、採用しない。

**理由**: `description` を**プロトコル要件**にすると、`CustomStringConvertible` に適合済みの型が後から `Tool` に適合した際、**デバッグ用の `description` が LLM 向け説明として無言で採用される**。コンパイルエラーは出ないため、誤った文字列がプロンプトに載るまで気づけない。実測:

```swift
struct LoggingTool: CustomStringConvertible {
    var description: String { "LoggingTool(id: 42)" }   // デバッグ用のつもり
}
extension LoggingTool: Tool {                            // 後から Tool 適合を足す
    var name: String { "logging" }
}
// → description 要件は既存のデバッグ表現で満たされ、それが LLM に送られる
```

現行設計はこれを構造的に回避している。LLM へ渡るペイロードを組み立てる `Tool.definition`
（`ToolDefinition.swift`）は、alias ではなく曖昧さのない要件 `toolName` / `toolDescription`
を読む。一方で呼び出し側の書き味のために `extension Tool` が `name` / `description` を
提供しており、`any Tool` / ジェネリック経由ではプロトコル拡張が解決されるため要件と一致する
（具象型が独自の `name` を持つ場合のみ具象側が優先されるが、これは呼び出し側の表示用途に閉じる）。

**費用対効果**: 改名の波及はワークスペース全体で 343 箇所・17 パッケージ（列車対象外の
KyoichiAI を含む）。得られるのは、呼び出し側がほとんど直接書かない要件名の
「Omit needless words」適合のみ。安全性を落として払うコストとして見合わない。

**再検討の条件**: `Tool` から `description` 由来の曖昧さを排除できる言語機能（要件の
明示的 disambiguation 等）が入った場合、または `Tool` 適合型が `CustomStringConvertible`
に適合しないことを機械的に保証できるようになった場合。

判断日: 2026-07-19
