import Foundation
import LLMClient

// MARK: - ToolCallResponse

/// What the model decided to call, before anything has been called.
///
/// Holds the planned calls and nothing else has happened yet: running them is the caller's
/// job. A response may carry text and calls together, or text alone when the model chose to
/// answer directly.
///
/// ## Example
///
/// ```swift
/// let client = AnthropicClient(apiKey: "...")
///
/// @Tool("Returns the weather")
/// struct GetWeather {
///     @ToolArgument("Location")
///     var location: String
///
///     func call() async throws -> String {
///         // Call the weather API
///         return "Sunny, 25 degrees"
///     }
/// }
///
/// let tools = ToolSet {
///     GetWeather()
/// }
///
/// // Let the model plan which tools to call
/// let plan = try await client.planToolCalls(
///     prompt: "Tell me the weather in Tokyo",
///     model: .sonnet,
///     tools: tools
/// )
///
/// // Run the planned calls
/// for call in plan.toolCalls {
///     let result = try await tools.execute(toolNamed: call.name, with: call.arguments)
///     print(result)
/// }
/// ```
public struct ToolCallResponse: Sendable {
    /// The calls the model asked for, in the order it emitted them.
    ///
    /// A model may ask for several at once. The calls carry no dependency on each other, so
    /// they can be run concurrently, but each one has to come back as a result carrying its
    /// own id before the conversation can continue.
    public let toolCalls: [ToolCall]

    /// Text the model produced alongside the plan, such as an explanation of what it is about
    /// to do. Present or absent independently of whether there are calls.
    public let text: String?

    /// Tokens spent planning, which is this request alone.
    ///
    /// Tool definitions travel with every request and are counted as input, so the cost scales
    /// with the size of the tool set rather than with the number of tools actually called.
    /// Running the tools and sending their results back is a separate request with its own cost.
    public let usage: TokenUsage

    /// Why the model stopped generating.
    ///
    /// A tool-use reason means it paused to wait for results and expects the conversation to
    /// continue. A max-tokens reason means the reply was cut off, which can leave argument JSON
    /// truncated and undecodable.
    public let stopReason: LLMResponse.StopReason?

    /// The model id the provider reported serving the request, which may be more specific than
    /// the alias that was requested.
    public let model: String

    /// Whether the model asked for any tool to be run.
    public var hasToolCalls: Bool {
        !toolCalls.isEmpty
    }

    // MARK: - Initializer

    /// Creates a planned response, normally from a provider adapter parsing a reply.
    ///
    /// - Parameters:
    ///   - toolCalls: The calls, in the order the model emitted them.
    ///   - text: Text produced alongside the calls.
    ///   - usage: Tokens spent on this request.
    ///   - stopReason: Why the model stopped generating.
    ///   - model: The model id the provider reported.
    public init(
        toolCalls: [ToolCall],
        text: String?,
        usage: TokenUsage,
        stopReason: LLMResponse.StopReason?,
        model: String
    ) {
        self.toolCalls = toolCalls
        self.text = text
        self.usage = usage
        self.stopReason = stopReason
        self.model = model
    }
}
