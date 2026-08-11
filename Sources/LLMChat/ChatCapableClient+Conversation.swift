import Foundation
import LLMClient

// MARK: - ChatCapableClient + Conversation

extension ChatCapableClient {
    /// Runs one turn against a conversation history, appending both sides of it for you.
    ///
    /// The user message goes into the history, the request is sent with the history as it then
    /// stands, and the assistant message and token usage are appended on success. Because the
    /// history holds plain messages rather than provider state, the same history can be carried
    /// from one provider to another mid-conversation.
    ///
    /// On failure the user message stays in the history — it is appended before the request and is
    /// never rolled back — and an error event is emitted before the error is rethrown. Retrying by
    /// calling again with the same input appends that message a second time, so drop or repair the
    /// history first.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let history = ConversationHistory()
    ///
    /// // Open the conversation with Claude.
    /// let claude = AnthropicClient(apiKey: "...")
    /// let city: CityInfo = try await claude.chat(
    ///     input: "What is the capital of Japan?",
    ///     history: history,
    ///     model: .sonnet
    /// )
    ///
    /// // Continue the same history with GPT.
    /// let openai = OpenAIClient(apiKey: "...")
    /// let population: PopulationInfo = try await openai.chat(
    ///     input: "What is that city's population?",
    ///     history: history,
    ///     model: .gpt4o
    /// )
    ///
    /// // Multimodal input.
    /// let analysis: ImageAnalysis = try await claude.chat(
    ///     input: LLMInput("Analyse this image.", images: [imageContent]),
    ///     history: history,
    ///     model: .sonnet
    /// )
    /// ```
    ///
    /// ## Observing the turn
    ///
    /// The history's `eventStream` reports each message as it is appended and each usage update,
    /// which is how a UI follows a turn it did not itself drive.
    ///
    /// ```swift
    /// Task {
    ///     for await event in history.eventStream {
    ///         // Update the UI.
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - input: The prompt, optionally carrying images, audio, or video.
    ///   - history: The conversation to read from and append to.
    ///   - model: The model to serve the request.
    ///   - systemPrompt: Instructions applied ahead of the history. Not stored in the history, so
    ///     it must be passed again on every turn.
    ///   - temperature: Sampling temperature. Passed through unvalidated; the accepted range
    ///     differs by provider.
    ///   - maxTokens: Ceiling on output tokens.
    /// - Returns: The decoded value. Everything else about the turn is left in the history.
    /// - Throws: `LLMError`. Any other error is wrapped as `LLMError.networkError` first, so a
    ///   caller only ever has one error type to match on.
    public func chat<T: StructuredProtocol, History: ConversationHistoryProtocol>(
        input: LLMInput,
        history: History,
        model: Model,
        systemPrompt: SystemPrompt? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> T {
        // 1. Add the user message to the history.
        await history.append(input.toLLMMessage())

        do {
            // 2. Call the API with the history as it now stands.
            let messages = await history.getMessages()
            let response: ChatResponse<T> = try await chat(
                messages: messages,
                model: model,
                systemPrompt: systemPrompt?.render(),
                temperature: temperature,
                maxTokens: maxTokens
            )

            // 3. Add the assistant message to the history.
            await history.append(response.assistantMessage)

            // 4. Accumulate the token usage.
            await history.addUsage(response.usage)

            return response.result
        } catch let llmError as LLMError {
            // Emit an error event.
            await history.emitError(llmError)
            throw llmError
        } catch {
            // Wrap an unrecognised error as an LLMError.
            let llmError = LLMError.networkError(error)
            await history.emitError(llmError)
            throw llmError
        }
    }

    /// Runs one turn against a conversation history and hands back the whole response.
    ///
    /// Identical to the value-returning form except that the per-turn token usage, the stop reason,
    /// the served model identifier, and the raw JSON survive the call. Reach for it wherever a
    /// single turn has to be costed or a truncated response detected, since the running total on
    /// the history cannot answer either question.
    ///
    /// - Parameters:
    ///   - input: The prompt, optionally carrying images, audio, or video.
    ///   - history: The conversation to read from and append to.
    ///   - model: The model to serve the request.
    ///   - systemPrompt: Instructions applied ahead of the history.
    ///   - temperature: Sampling temperature. Passed through unvalidated; the accepted range
    ///     differs by provider.
    ///   - maxTokens: Ceiling on output tokens.
    /// - Returns: The decoded value together with the metadata of this one turn.
    /// - Throws: `LLMError`. Any other error is wrapped as `LLMError.networkError` first.
    public func chatWithDetails<T: StructuredProtocol, History: ConversationHistoryProtocol>(
        input: LLMInput,
        history: History,
        model: Model,
        systemPrompt: SystemPrompt? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> ChatResponse<T> {
        // 1. Add the user message to the history.
        await history.append(input.toLLMMessage())

        do {
            // 2. Call the API with the history as it now stands.
            let messages = await history.getMessages()
            let response: ChatResponse<T> = try await chat(
                messages: messages,
                model: model,
                systemPrompt: systemPrompt?.render(),
                temperature: temperature,
                maxTokens: maxTokens
            )

            // 3. Add the assistant message to the history.
            await history.append(response.assistantMessage)

            // 4. Accumulate the token usage.
            await history.addUsage(response.usage)

            return response
        } catch let llmError as LLMError {
            // Emit an error event.
            await history.emitError(llmError)
            throw llmError
        } catch {
            // Wrap an unrecognised error as an LLMError.
            let llmError = LLMError.networkError(error)
            await history.emitError(llmError)
            throw llmError
        }
    }
}
