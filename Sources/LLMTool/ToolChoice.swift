import Foundation

// MARK: - ToolChoice

/// How much freedom the model has in choosing a tool.
///
/// Each case is translated into the provider's own tool-choice field, so the same value works
/// across providers. Forcing a choice applies to one request only: leave it forced on a loop
/// and the model can never produce the final answer, so the usual pattern is to force the first
/// request and fall back to automatic selection afterwards.
///
/// ## Example
///
/// ```swift
/// // Automatic selection
/// let plan = try await client.planToolCalls(
///     prompt: "What is the weather in Tokyo?",
///     model: .sonnet,
///     tools: tools,
///     toolChoice: .auto
/// )
///
/// // Require some tool to be used
/// let plan = try await client.planToolCalls(
///     prompt: "Look up the weather",
///     model: .sonnet,
///     tools: tools,
///     toolChoice: .required
/// )
///
/// // Require one particular tool
/// let plan = try await client.planToolCalls(
///     prompt: "Look up the weather",
///     model: .sonnet,
///     tools: tools,
///     toolChoice: .tool("get_weather")
/// )
/// ```
public enum ToolChoice: Sendable, Equatable {

    /// Lets the model decide, which is what providers do when no choice is given.
    ///
    /// It may answer with text alone when no tool is warranted, so a caller cannot assume the
    /// response carries calls.
    case auto

    /// Requires the model to call a tool, leaving it to pick which one.
    ///
    /// Use it when an empty-handed answer is not an acceptable outcome, such as a router whose
    /// whole job is to dispatch to one of its tools.
    case required

    /// Asks for a text-only answer even though tools are attached.
    ///
    /// Useful for a final summarizing turn where the tools stay in the prompt, and therefore
    /// stay cached, but must not fire again. Support is uneven: some adapters map it to the
    /// provider's own suppression field, while others fall through to automatic selection, so
    /// confirm with the provider before relying on it to hard-block a call.
    case disabled

    /// Requires the model to call one named tool.
    ///
    /// The most direct way to get structured arguments out of a model: define one tool, force
    /// it, and read its arguments. The name has to match a tool present in the request.
    ///
    /// - Parameter name: The name of the tool the model has to call.
    case tool(String)
}

// MARK: - Parallel Tool Use

/// Whether the model may ask for several tool calls in one reply.
///
/// No request builder reads this value, so passing it does not reach the provider and parallel
/// tool use follows each provider's own default. Check the response instead: a plan can carry
/// more than one call whatever this says.
public enum ParallelToolUse: Sendable, Equatable {

    /// Several calls may come back in a single reply.
    case enabled

    /// At most one call comes back per reply, which serializes a multi-step task into one
    /// round trip per step.
    case disabled
}
