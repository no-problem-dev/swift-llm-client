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
/// 指定する。`ThinkingMode` が「on / off」のスイッチであるのに対し、
/// こちらは OpenAI 固有の effort 階級を表す独立した設定。
///
/// **受け付ける値はモデルによって違う。** 非対応の値を送るとリクエストが弾かれる
/// （`invalid_request_error`）ので、`GPTModel.supports(_:)` で確かめてから送る。
public enum ReasoningEffort: String, Sendable, Equatable, CaseIterable {
    /// 思考しない。最速・最安。
    ///
    /// - Note: `ReasoningEffort?` と比べるときは `Optional.none` と紛れる。
    ///   `== ReasoningEffort.none` と型を明示する。
    case none
    /// 思考トークンを最小化。
    ///
    /// - Warning: **現行モデルは受け付けない。** GPT-5.3 以降で `none` に置き換わった。
    ///   古いモデル（o-series・GPT-5 / 5.1 / 5.2）向けに残してある。
    case minimal
    /// 浅い思考。triage / 簡単な編集 / 軽量な多段 tool routing 向け。
    case low
    /// 既定。汎用ワークロードに対する safe choice。
    case medium
    /// 深い多段思考。計画立案・複雑な分析向け。
    case high
    /// high より深い思考。
    case xhigh
    /// 最も深い思考。GPT-5.6 系のみ。
    case max
}
