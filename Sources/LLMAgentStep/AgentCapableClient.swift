import Foundation
import LLMClient
import LLMTool

// MARK: - AgentCapableClient Protocol

/// A client that can serve one step of an agent loop, streamed or not.
///
/// Extends `ToolCallableClient` with the request shape an agent loop needs: the conversation so
/// far, the tools, and optionally the schema the final answer must match, in a single call. The
/// loop itself — running the tools, appending their results, deciding whether to go round again —
/// is not here; this protocol only supplies the step.
public protocol AgentCapableClient: ToolCallableClient {
    /// Runs one step of an agent loop and waits for the whole response.
    ///
    /// One request, one response. The response either holds the tool calls the model wants made,
    /// in which case the caller runs them and appends the results before stepping again, or holds
    /// the answer.
    ///
    /// - Parameters:
    ///   - messages: The conversation so far, oldest first, including the results of tools that
    ///     have already run.
    ///   - model: The model to serve the request.
    ///   - systemPrompt: Instructions applied ahead of the conversation.
    ///   - tools: The tools the model may choose from.
    ///   - toolChoice: Constrains that choice. Automatic selection when omitted.
    ///   - responseSchema: The schema the final answer must match, or nil while the loop is still
    ///     calling tools.
    ///   - thinkingMode: Whether extended thinking is available to the model.
    ///   - reasoningEffort: The `reasoning_effort` of OpenAI's reasoning models. Ignored by
    ///     providers that have no such parameter.
    ///   - maxTokens: Ceiling on output tokens, or nil for the provider default.
    ///   - cachePolicy: How to cache the stable prefix, meaning the system prompt and the tool
    ///     definitions. Tool definitions are resent on every step and are often the largest part
    ///     of the prompt, so caching them is what keeps a long loop cheap.
    func executeAgentStep(
        messages: [LLMMessage],
        model: Model,
        systemPrompt: SystemPrompt?,
        tools: ToolSet,
        toolChoice: ToolChoice?,
        responseSchema: JSONSchema?,
        thinkingMode: ThinkingMode,
        reasoningEffort: ReasoningEffort?,
        maxTokens: Int?,
        cachePolicy: PromptCachePolicy
    ) async throws -> LLMResponse

    /// Runs one step of an agent loop, emitting thinking and text as it is produced.
    ///
    /// The stream ends with a `.completed` event carrying the same full response the non-streaming
    /// form returns. Deltas are an optimisation for showing progress, and are not guaranteed:
    /// tool-call arguments never stream, and a provider without native streaming falls back to the
    /// default implementation, which emits the completed event alone. Render the completed
    /// response as well, or such a provider shows nothing at all.
    ///
    /// - Parameters:
    ///   - messages: The conversation so far, oldest first.
    ///   - model: The model to serve the request.
    ///   - systemPrompt: Instructions applied ahead of the conversation.
    ///   - tools: The tools the model may choose from.
    ///   - toolChoice: Constrains that choice. Automatic selection when omitted.
    ///   - responseSchema: The schema the final answer must match, or nil while the loop is still
    ///     calling tools.
    ///   - thinkingMode: Whether extended thinking is available to the model.
    ///   - reasoningEffort: The `reasoning_effort` of OpenAI's reasoning models. Ignored by
    ///     providers that have no such parameter.
    ///   - maxTokens: Ceiling on output tokens, or nil for the provider default.
    ///   - cachePolicy: How to cache the stable prefix, meaning the system prompt and the tool
    ///     definitions.
    /// - Returns: A stream of deltas closed by exactly one completed event, or thrown from if the
    ///   request fails.
    func streamAgentStep(
        messages: [LLMMessage],
        model: Model,
        systemPrompt: SystemPrompt?,
        tools: ToolSet,
        toolChoice: ToolChoice?,
        responseSchema: JSONSchema?,
        thinkingMode: ThinkingMode,
        reasoningEffort: ReasoningEffort?,
        maxTokens: Int?,
        cachePolicy: PromptCachePolicy
    ) -> AsyncThrowingStream<StreamingAgentEvent, Error>
}

// MARK: - Default Implementation

extension AgentCapableClient {
    /// Satisfies the streaming requirement by running the non-streaming call, so nothing streams.
    ///
    /// A provider with no native streaming conforms through this: it awaits the whole response,
    /// yields one completed event, and finishes. No delta is ever emitted, so a caller can be
    /// handed a stream that never streams, with the entire answer arriving at once at the end. A
    /// UI that draws only from deltas therefore stays blank on such a provider — which is a fact
    /// about the provider, not a fault to work around. Override this to stream natively.
    ///
    /// Abandoning the stream cancels the task running the request, so a dropped consumer does not
    /// leave a call generating billable tokens nobody will read.
    public func streamAgentStep(
        messages: [LLMMessage],
        model: Model,
        systemPrompt: SystemPrompt?,
        tools: ToolSet,
        toolChoice: ToolChoice?,
        responseSchema: JSONSchema?,
        thinkingMode: ThinkingMode,
        reasoningEffort: ReasoningEffort?,
        maxTokens: Int?,
        cachePolicy: PromptCachePolicy
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
                        maxTokens: maxTokens,
                        cachePolicy: cachePolicy
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
