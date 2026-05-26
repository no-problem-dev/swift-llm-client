import Foundation
import LLMClient

// MARK: - AgentCapableClient Protocol

/// エージェントループをサポートするクライアントのプロトコル
///
/// `ToolCallableClient` を拡張し、エージェントループの実装に必要な
/// メソッドを提供します。各プロバイダーはこのプロトコルに適合することで
/// エージェント機能を利用可能にします。
public protocol AgentCapableClient: ToolCallableClient {
    /// エージェントステップを実行
    ///
    /// メッセージ履歴、ツール、オプションの構造化出力スキーマを含むリクエストを送信します。
    ///
    /// - Parameters:
    ///   - messages: メッセージ履歴
    ///   - model: 使用するモデル
    ///   - systemPrompt: システムプロンプト
    ///   - tools: 使用可能なツール
    ///   - toolChoice: ツール選択設定
    ///   - responseSchema: 期待する出力スキーマ（最終出力用）
    ///   - thinkingMode: Extended Thinking のモード
    ///   - reasoningEffort: OpenAI reasoning モデルの `reasoning_effort`（非対応プロバイダーは無視）
    ///   - maxTokens: 最大出力トークン数（nil の場合はプロバイダーのデフォルト値を使用）
    /// - Returns: LLM レスポンス
    func executeAgentStep(
        messages: [LLMMessage],
        model: Model,
        systemPrompt: SystemPrompt?,
        tools: ToolSet,
        toolChoice: ToolChoice?,
        responseSchema: JSONSchema?,
        thinkingMode: ThinkingMode,
        reasoningEffort: ReasoningEffort?,
        maxTokens: Int?
    ) async throws -> LLMResponse

    /// エージェントステップをストリーミング実行
    ///
    /// thinking delta やテキスト delta をリアルタイムに返し、
    /// 最終的に完全な `LLMResponse` を返します。
    ///
    /// - Parameters:
    ///   - messages: メッセージ履歴
    ///   - model: 使用するモデル
    ///   - systemPrompt: システムプロンプト
    ///   - tools: 使用可能なツール
    ///   - toolChoice: ツール選択設定
    ///   - responseSchema: 期待する出力スキーマ
    ///   - thinkingMode: Extended Thinking のモード
    ///   - reasoningEffort: OpenAI reasoning モデルの `reasoning_effort`（非対応プロバイダーは無視）
    ///   - maxTokens: 最大出力トークン数（nil の場合はプロバイダーのデフォルト値を使用）
    /// - Returns: ストリーミングイベントの AsyncThrowingStream
    func streamAgentStep(
        messages: [LLMMessage],
        model: Model,
        systemPrompt: SystemPrompt?,
        tools: ToolSet,
        toolChoice: ToolChoice?,
        responseSchema: JSONSchema?,
        thinkingMode: ThinkingMode,
        reasoningEffort: ReasoningEffort?,
        maxTokens: Int?
    ) -> AsyncThrowingStream<StreamingAgentEvent, Error>
}

// MARK: - Default Implementation

extension AgentCapableClient {
    /// デフォルト実装: 非ストリーミングの `executeAgentStep` をラップ
    ///
    /// Anthropic 以外のプロバイダー（OpenAI, Gemini, Local）はこのデフォルト実装を使用します。
    public func streamAgentStep(
        messages: [LLMMessage],
        model: Model,
        systemPrompt: SystemPrompt?,
        tools: ToolSet,
        toolChoice: ToolChoice?,
        responseSchema: JSONSchema?,
        thinkingMode: ThinkingMode,
        reasoningEffort: ReasoningEffort?,
        maxTokens: Int?
    ) -> AsyncThrowingStream<StreamingAgentEvent, Error> {
        makeCancellableStream { continuation in
            Task {
                do {
                    let response = try await executeAgentStep(
                        messages: messages,
                        model: model,
                        systemPrompt: systemPrompt,
                        tools: tools,
                        toolChoice: toolChoice,
                        responseSchema: responseSchema,
                        thinkingMode: thinkingMode,
                        reasoningEffort: reasoningEffort,
                        maxTokens: maxTokens
                    )
                    continuation.yield(.completed(response))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
