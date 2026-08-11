import Foundation
import LLMClient

// MARK: - ToolCallableClient Protocol

/// A client that can offer tools to the model and report back which ones it wants to call.
///
/// Adds tool calling on top of structured output. Each provider — Anthropic, OpenAI, Gemini —
/// conforms to it so that callers can hand over the same tool set regardless of which one is
/// behind the client.
///
/// ## Example
///
/// ```swift
/// let client = AnthropicClient(apiKey: "sk-ant-...")
///
/// @Tool("Returns the weather")
/// struct GetWeather {
///     @ToolArgument("Location")
///     var location: String
///
///     func call() async throws -> String {
///         return "Sunny"
///     }
/// }
///
/// let tools = ToolSet {
///     GetWeather()
/// }
///
/// let response = try await client.planToolCalls(
///     prompt: "What is the weather in Tokyo?",
///     model: .sonnet,
///     tools: tools
/// )
/// ```
public protocol ToolCallableClient: StructuredLLMClient {
    /// Asks the model which tools to call for a single prompt, without calling any of them.
    ///
    /// This is one request and one response. The model picks tools and fills in arguments; no
    /// tool ever runs here, and nothing is fed back to the model. Running the calls, appending
    /// the results to the conversation, and deciding whether to go around again are all the
    /// caller's job. Use an agent run instead when that loop should be driven for you.
    ///
    /// - Parameters:
    ///   - prompt: The user prompt.
    ///   - model: The model to ask.
    ///   - tools: The tools the model may choose from.
    ///   - toolChoice: Constrains that choice. Automatic selection when omitted.
    ///   - systemPrompt: System instructions for the request.
    ///   - temperature: Sampling temperature.
    ///   - maxTokens: Upper bound on tokens the model may generate in its reply.
    ///   - cachePolicy: How to cache the stable prefix, meaning the system prompt and the tool
    ///     definitions. Tool definitions are resent on every request and are often the largest
    ///     part of the prompt, so caching them is what keeps a tool-heavy conversation cheap.
    /// - Returns: The planned calls, along with any text the model produced alongside them.
    func planToolCalls(
        prompt: String,
        model: Model,
        tools: ToolSet,
        toolChoice: ToolChoice?,
        systemPrompt: SystemPrompt?,
        temperature: Double?,
        maxTokens: Int?,
        cachePolicy: PromptCachePolicy
    ) async throws -> ToolCallResponse

    /// Asks the model which tools to call given a conversation, without calling any of them.
    ///
    /// The form to use once tools have already run: append the assistant message holding the
    /// previous calls and the tool results answering them, then ask again. Every earlier call
    /// has to be answered by a result carrying its id, or providers reject the request.
    ///
    /// - Parameters:
    ///   - messages: The conversation so far.
    ///   - model: The model to ask.
    ///   - tools: The tools the model may choose from.
    ///   - toolChoice: Constrains that choice. Automatic selection when omitted.
    ///   - systemPrompt: System instructions for the request.
    ///   - temperature: Sampling temperature.
    ///   - maxTokens: Upper bound on tokens the model may generate in its reply.
    ///   - cachePolicy: How to cache the stable prefix, meaning the system prompt and the tool
    ///     definitions. Tool definitions are resent on every request and are often the largest
    ///     part of the prompt, so caching them is what keeps a tool-heavy conversation cheap.
    /// - Returns: The planned calls, along with any text the model produced alongside them.
    func planToolCalls(
        messages: [LLMMessage],
        model: Model,
        tools: ToolSet,
        toolChoice: ToolChoice?,
        systemPrompt: SystemPrompt?,
        temperature: Double?,
        maxTokens: Int?,
        cachePolicy: PromptCachePolicy
    ) async throws -> ToolCallResponse
}

// MARK: - Default Implementations

extension ToolCallableClient {
    /// Wraps the prompt in a one-message conversation and forwards it, so conformers only have
    /// to implement the conversation form.
    public func planToolCalls(
        prompt: String,
        model: Model,
        tools: ToolSet,
        toolChoice: ToolChoice? = nil,
        systemPrompt: SystemPrompt? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        cachePolicy: PromptCachePolicy = .implicit
    ) async throws -> ToolCallResponse {
        try await planToolCalls(
            messages: [.user(prompt)],
            model: model,
            tools: tools,
            toolChoice: toolChoice,
            systemPrompt: systemPrompt,
            temperature: temperature,
            maxTokens: maxTokens,
            cachePolicy: cachePolicy
        )
    }
}
