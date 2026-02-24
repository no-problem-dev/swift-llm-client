import Foundation

// MARK: - StreamDelta

/// ストリーミング中の差分イベント
public enum StreamDelta: Sendable {
    /// 思考テキストの差分
    case thinkingDelta(String)

    /// テキストコンテンツの差分
    case textDelta(String)
}

// MARK: - StreamingAgentEvent

/// ストリーミングエージェントステップのイベント
///
/// エージェントループ内の LLM 呼び出しをストリーミングする際に使用します。
/// - `.delta`: ストリーミング中の差分（thinking/text）
/// - `.completed`: ストリーミング完了後の完全なレスポンス
public enum StreamingAgentEvent: Sendable {
    /// ストリーミング中の差分イベント
    case delta(StreamDelta)

    /// ストリーミング完了、完全なレスポンス
    case completed(LLMResponse)
}

// MARK: - ThinkingMode

/// Extended Thinking のモード設定
public enum ThinkingMode: Sendable, Equatable {
    /// Thinking 無効
    case disabled

    /// Adaptive モード（API が必要に応じて thinking を使用）
    case adaptive
}
