import Foundation
import LLMClient

// MARK: - TokenCounting

/// Counts what a request will occupy in the context window before it is sent.
///
/// There is no general local tokenizer to reach for: Anthropic exposes
/// `/v1/messages/count_tokens`, a local model carries its own tokenizer, and every provider
/// counts a slightly different thing. Counting is therefore modelled as a port and left to each
/// provider's adapter, so the layers above stay provider-independent.
///
/// The port lives in the lowest layer where the system prompt, the tools and the messages are
/// all in hand: `LLMRequest` itself carries no tools, and tools only join the request here.
///
/// Adapters such as the Anthropic cloud client implement it, and the segment breakdown engine
/// calls it repeatedly to attribute tokens to categories by subtraction.
public protocol TokenCounting: Sendable {

    /// Returns the total input tokens for the given system prompt, tools and messages.
    ///
    /// The number covers the request as the provider will see it — the system prompt, every
    /// tool's name, description and argument schema, and every message. It does not cover the
    /// completion the model has yet to produce.
    ///
    /// - Note: Implementations return a pre-flight estimate (`count_tokens` or equivalent), not
    ///   the `usage` figures that come back attached to a response. The adapter must run **the
    ///   same conversion path a real request runs** — matching `cache_control` placement, tool
    ///   schemas and system blocks — so the estimate does not drift away from the request that is
    ///   actually billed.
    ///
    /// - Note: Counts are not additive. Each call carries the provider's own hidden per-request
    ///   wrapper, so counting segments separately and summing them charges that wrapper once per
    ///   segment. Attribute a segment by differencing two counts that vary only in that segment.
    ///
    /// - Parameters:
    ///   - modelID: The model whose tokenizer applies.
    ///   - systemPrompt: The system prompt, or `nil` to leave it out of the count.
    ///   - messages: The conversation to count.
    ///   - tools: The tools whose definitions to count, or `nil` to count none.
    func countInputTokens(
        modelID: String,
        systemPrompt: String?,
        messages: [LLMMessage],
        tools: ToolSet?
    ) async throws -> Int
}
