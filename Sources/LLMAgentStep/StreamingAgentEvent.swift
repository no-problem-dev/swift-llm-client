import LLMClient

/// エージェントステップのストリーミングイベント。
///
/// `AgentCapableClient.streamAgentStep` のステップ契約の一部。
/// 純粋なモデルアクセス層の外に置かれる：
/// - `.delta`: 進行中の thinking / テキスト差分。
/// - `.completed`: ステップ完了時の完全なレスポンス。
public enum StreamingAgentEvent: Sendable {
    case delta(StreamDelta)
    case completed(LLMResponse)
}
