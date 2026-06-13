import Foundation

// MARK: - StreamDelta

/// ストリーミング中の差分イベント
public enum StreamDelta: Sendable {
    /// 思考テキストの差分
    case thinkingDelta(String)

    /// テキストコンテンツの差分
    case textDelta(String)
}

// MARK: - ThinkingMode

/// Extended Thinking のモード設定
public enum ThinkingMode: Sendable, Equatable {
    /// Thinking 無効
    case disabled

    /// Adaptive モード（API が必要に応じて thinking を使用）
    case adaptive
}

// MARK: - ReasoningEffort

/// OpenAI GPT-5 系の `reasoning_effort` パラメータ。
///
/// reasoning モデルに対して、思考ステップにかけるトークン数（＝速度／コスト／精度）を
/// 4 段階で指定する。`ThinkingMode` が「on / off」のスイッチであるのに対し、
/// こちらは OpenAI 固有の effort 階級を表す独立した設定。
///
/// - Note: `.minimal` では parallel tool call が無効化される（OpenAI 仕様）。
///   並列ツール呼び出しが必要な場合は `.low` 以上を選ぶこと。
public enum ReasoningEffort: String, Sendable, Equatable, CaseIterable {
    /// 思考トークンを最小化。最速・最安だが parallel tool call 不可。
    case minimal
    /// 浅い思考。triage / 簡単な編集 / 軽量な多段 tool routing 向け。
    case low
    /// 既定。汎用ワークロードに対する safe choice。
    case medium
    /// 深い多段思考。計画立案・複雑な分析向け。最も遅く高価。
    case high
}
