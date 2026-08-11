import Foundation
import LLMClient

// MARK: - ChatResponse

/// One turn's result: the decoded value plus everything the turn after it needs.
///
/// The decoded value is only half of what a conversation needs. The other half is
/// `assistantMessage`, which has to reach the history before the next request goes out; forget it
/// and later turns are answered as though the model had never replied.
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
/// print(response2.result.population)  // 13960000
/// ```
public struct ChatResponse<T: StructuredProtocol>: Sendable {
    /// The model's JSON parsed into the result type the call named.
    public let result: T

    /// The model's reply as a message, ready to be appended to the conversation history.
    ///
    /// Appending it is what makes the next turn a continuation rather than a fresh start. Nothing
    /// checks that it was appended, so an omission shows up only as a model that has forgotten
    /// what it just said.
    public let assistantMessage: LLMMessage

    /// What this one request consumed, not a running total across the conversation.
    ///
    /// The input count covers the whole history that was resent, cached tokens included, so it
    /// climbs from turn to turn even when the new question is short. Add these up yourself, or let
    /// a conversation history do it, to cost a whole conversation.
    public let usage: TokenUsage

    /// Why the model stopped generating, or nil when the provider did not say.
    ///
    /// `.maxTokens` means the output was cut off at the ceiling. Truncated JSON usually fails to
    /// decode before this value is ever seen, so treat it as the explanation for a decoding
    /// failure rather than as a check to run on a successful result.
    public let stopReason: LLMResponse.StopReason?

    /// The model identifier the provider actually served.
    ///
    /// A provider may resolve an alias to a dated build, so this can differ from the model that
    /// was asked for. It is the identifier to record when attributing cost.
    public let model: String

    /// The raw JSON text the model returned, before decoding.
    ///
    /// Worth logging when a decode fails or a field arrives empty, since it is the only view of
    /// what the model actually produced.
    public let rawText: String

    // MARK: - Initializer

    /// Creates a chat response.
    ///
    /// - Parameters:
    ///   - result: The decoded value.
    ///   - assistantMessage: The model's reply as a message for the history.
    ///   - usage: What this one request consumed.
    ///   - stopReason: Why the model stopped, or nil when the provider did not say.
    ///   - model: The model identifier the provider actually served.
    ///   - rawText: The raw JSON text the model returned.
    public init(
        result: T,
        assistantMessage: LLMMessage,
        usage: TokenUsage,
        stopReason: LLMResponse.StopReason?,
        model: String,
        rawText: String
    ) {
        self.result = result
        self.assistantMessage = assistantMessage
        self.usage = usage
        self.stopReason = stopReason
        self.model = model
        self.rawText = rawText
    }
}
