import Foundation
import LLMClient

// MARK: - ChatCapableClient Protocol

/// A client that returns, alongside the decoded value, what the next turn of a conversation needs.
///
/// Extends `StructuredLLMClient`. Where `generate` hands back the decoded value and nothing else,
/// `chat` also hands back the assistant message to append to the history, the token usage of the
/// turn, and the stop reason. The history is an array the caller owns rather than server-side
/// state, so a conversation started against one provider can be continued against another.
///
/// The whole history goes out on every call, so input tokens grow with the conversation.
///
/// ## Example
///
/// ```swift
/// let client = AnthropicClient(apiKey: "...")
/// var history: [LLMMessage] = []
///
/// // First question.
/// history.append(.user("What is the capital of Japan?"))
/// let response1: ChatResponse<CityInfo> = try await client.chat(
///     messages: history,
///     model: .sonnet
/// )
/// print(response1.result.name)  // "Tokyo"
///
/// // Append the assistant reply to the history.
/// history.append(response1.assistantMessage)
///
/// // Follow-up question.
/// history.append(.user("What is that city's population?"))
/// let response2: ChatResponse<PopulationInfo> = try await client.chat(
///     messages: history,
///     model: .sonnet
/// )
/// ```
public protocol ChatCapableClient: StructuredLLMClient {
    /// Continues a conversation, returning the decoded value together with what the next turn needs.
    ///
    /// Appending the response's `assistantMessage` to the history before the next call is the
    /// caller's job. Skip it and the model never sees its own previous reply: the next turn is
    /// answered as if it had not spoken, and nothing raises an error to say so.
    ///
    /// - Parameters:
    ///   - messages: The conversation so far, oldest first.
    ///   - model: The model to serve the request.
    ///   - systemPrompt: Instructions applied ahead of the history. Keeping it byte-identical
    ///     across turns is what lets a provider cache the prefix.
    ///   - temperature: Sampling temperature. Passed through unvalidated; the accepted range
    ///     differs by provider.
    ///   - maxTokens: Ceiling on output tokens. A ceiling low enough to cut the JSON short leaves
    ///     the response undecodable, so leave headroom above the expected result size.
    func chat<T: StructuredProtocol>(
        messages: [LLMMessage],
        model: Model,
        systemPrompt: String?,
        temperature: Double?,
        maxTokens: Int?
    ) async throws -> ChatResponse<T>
}

// MARK: - Default Implementations

extension ChatCapableClient {
    /// Continues a conversation, letting the optional arguments default.
    ///
    /// This exists only to supply default values, which a protocol requirement cannot declare. It
    /// forwards straight back through the protocol.
    ///
    /// - Warning: Its signature matches the requirement, so it can also stand in as the witness
    ///   for it. A conformance that omits `chat` therefore compiles and then recurses here forever
    ///   instead of failing to build.
    public func chat<T: StructuredProtocol>(
        messages: [LLMMessage],
        model: Model,
        systemPrompt: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> ChatResponse<T> {
        try await chat(
            messages: messages,
            model: model,
            systemPrompt: systemPrompt,
            temperature: temperature,
            maxTokens: maxTokens
        )
    }

    /// Opens a conversation from a single input, with no prior history.
    ///
    /// The input becomes the one and only message sent, so nothing said earlier is in context.
    /// Keep the returned `assistantMessage`, along with the message built from this input, to carry
    /// the conversation into a second turn.
    ///
    /// - Parameters:
    ///   - input: The prompt, optionally carrying images, audio, or video.
    ///   - model: The model to serve the request.
    ///   - systemPrompt: Instructions applied ahead of the input.
    ///   - temperature: Sampling temperature. Passed through unvalidated; the accepted range
    ///     differs by provider.
    ///   - maxTokens: Ceiling on output tokens.
    public func chat<T: StructuredProtocol>(
        input: LLMInput,
        model: Model,
        systemPrompt: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> ChatResponse<T> {
        try await chat(
            messages: [input.toLLMMessage()],
            model: model,
            systemPrompt: systemPrompt,
            temperature: temperature,
            maxTokens: maxTokens
        )
    }

    /// Opens a conversation from a single input, taking the system prompt as a composed value.
    ///
    /// Renders the prompt and forwards to the string form. Two prompts that render to the same
    /// bytes produce the same cacheable prefix, whatever metadata they carry.
    ///
    /// - Parameters:
    ///   - input: The prompt, optionally carrying images, audio, or video.
    ///   - model: The model to serve the request.
    ///   - systemPrompt: Instructions applied ahead of the input, rendered before they are sent.
    ///   - temperature: Sampling temperature. Passed through unvalidated; the accepted range
    ///     differs by provider.
    ///   - maxTokens: Ceiling on output tokens.
    public func chat<T: StructuredProtocol>(
        input: LLMInput,
        model: Model,
        systemPrompt: SystemPrompt,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> ChatResponse<T> {
        try await chat(
            input: input,
            model: model,
            systemPrompt: systemPrompt.render(),
            temperature: temperature,
            maxTokens: maxTokens
        )
    }
}
