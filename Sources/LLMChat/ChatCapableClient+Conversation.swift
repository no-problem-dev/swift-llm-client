import Foundation
import LLMClient

// MARK: - ChatCapableClient + Conversation

extension ChatCapableClient {
    /// 会話履歴を使用して構造化出力を生成
    ///
    /// ユーザーメッセージを履歴に追加し、LLM からの応答を取得して
    /// 履歴を更新する。履歴はモデルやクライアントから独立しているため、
    /// 同じ履歴を異なるプロバイダー・モデルで継続できる。
    ///
    /// ## 使用例
    ///
    /// ```swift
    /// let history = ConversationHistory()
    ///
    /// // Claude で会話開始
    /// let claude = AnthropicClient(apiKey: "...")
    /// let city: CityInfo = try await claude.chat(
    ///     input: "日本の首都は？",
    ///     history: history,
    ///     model: .sonnet
    /// )
    ///
    /// // 同じ履歴で GPT に切り替え
    /// let openai = OpenAIClient(apiKey: "...")
    /// let population: PopulationInfo = try await openai.chat(
    ///     input: "その都市の人口は？",
    ///     history: history,
    ///     model: .gpt4o
    /// )
    ///
    /// // マルチモーダル入力
    /// let analysis: ImageAnalysis = try await claude.chat(
    ///     input: LLMInput("この画像を分析してください", images: [imageContent]),
    ///     history: history,
    ///     model: .sonnet
    /// )
    /// ```
    ///
    /// ## イベント購読
    ///
    /// 履歴の `makeEventStream()` を使用して、
    /// メッセージの追加やトークン使用量の更新を購読できる。
    ///
    /// ```swift
    /// Task {
    ///     for await event in await history.makeEventStream() {
    ///         // UI を更新
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - input: LLM 入力（テキスト、画像、音声、動画を含む）
    ///   - history: 会話履歴（Actor で保護された状態）
    ///   - model: 使用するモデル
    ///   - systemPrompt: システムプロンプト（オプション）
    ///   - temperature: 温度パラメータ（オプション）
    ///   - maxTokens: 最大トークン数（オプション）
    /// - Returns: 指定された型にデコードされた構造化出力
    /// - Throws: `LLMError` - API エラー、デコードエラーなど
    public func chat<T: StructuredProtocol, History: ConversationHistoryProtocol>(
        input: LLMInput,
        history: History,
        model: Model,
        systemPrompt: SystemPrompt? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> T {
        // 1. ユーザーメッセージを履歴に追加
        await history.append(input.toLLMMessage())

        do {
            // 2. 現在の履歴でAPI呼び出し
            let messages = await history.getMessages()
            let response: ChatResponse<T> = try await chat(
                messages: messages,
                model: model,
                systemPrompt: systemPrompt?.render(),
                temperature: temperature,
                maxTokens: maxTokens
            )

            // 3. アシスタントメッセージを履歴に追加
            await history.append(response.assistantMessage)

            // 4. トークン使用量を累積
            await history.addUsage(response.usage)

            return response.result
        } catch let llmError as LLMError {
            // エラーイベントを発火
            await history.emitError(llmError)
            throw llmError
        } catch {
            // 不明なエラーを LLMError にラップ
            let llmError = LLMError.networkError(error)
            await history.emitError(llmError)
            throw llmError
        }
    }

    /// 会話履歴を使用して詳細な応答を取得
    ///
    /// 構造化出力に加えて、`ChatResponse` のメタ情報も取得したい場合に使用する。
    ///
    /// - Parameters:
    ///   - input: LLM 入力
    ///   - history: 会話履歴
    ///   - model: 使用するモデル
    ///   - systemPrompt: システムプロンプト（オプション）
    ///   - temperature: 温度パラメータ（オプション）
    ///   - maxTokens: 最大トークン数（オプション）
    /// - Returns: 構造化出力と会話継続情報を含む `ChatResponse`
    public func chatWithDetails<T: StructuredProtocol, History: ConversationHistoryProtocol>(
        input: LLMInput,
        history: History,
        model: Model,
        systemPrompt: SystemPrompt? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> ChatResponse<T> {
        // 1. ユーザーメッセージを履歴に追加
        await history.append(input.toLLMMessage())

        do {
            // 2. 現在の履歴でAPI呼び出し
            let messages = await history.getMessages()
            let response: ChatResponse<T> = try await chat(
                messages: messages,
                model: model,
                systemPrompt: systemPrompt?.render(),
                temperature: temperature,
                maxTokens: maxTokens
            )

            // 3. アシスタントメッセージを履歴に追加
            await history.append(response.assistantMessage)

            // 4. トークン使用量を累積
            await history.addUsage(response.usage)

            return response
        } catch let llmError as LLMError {
            // エラーイベントを発火
            await history.emitError(llmError)
            throw llmError
        } catch {
            // 不明なエラーを LLMError にラップ
            let llmError = LLMError.networkError(error)
            await history.emitError(llmError)
            throw llmError
        }
    }
}
