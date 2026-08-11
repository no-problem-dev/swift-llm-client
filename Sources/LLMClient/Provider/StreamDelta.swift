import Foundation

// MARK: - StreamDelta

/// One incremental fragment of a response as it is being generated.
///
/// Each delta carries only the newly produced characters, not a running snapshot — append them to
/// build the text; assigning instead leaves you with the last fragment alone.
///
/// Two things this deliberately does not carry. **Tool calls do not stream**: there is no case for
/// tool-call arguments, so an argument JSON blob only ever becomes visible on the finished
/// `LLMResponse` delivered by `StreamingAgentEvent.completed`. And a provider without native
/// streaming emits **no deltas at all** — `AgentCapableClient` supplies a default `streamAgentStep`
/// that runs the non-streaming call and yields a single `.completed`, so a UI must render the
/// completed response as well, not only the deltas.
public enum StreamDelta: Sendable {
    /// Newly produced reasoning text, when the model exposes its thinking.
    case thinkingDelta(String)

    /// Newly produced response text.
    case textDelta(String)
}

// MARK: - ThinkingMode

/// Whether extended thinking is available to the model.
///
/// A switch, not a budget: there is no token allowance to set here. For finer control over how
/// much reasoning is spent, see `ReasoningEffort`, which is a separate OpenAI-specific setting.
public enum ThinkingMode: Sendable, Equatable {
    /// No thinking. Also the right choice for models that do not support it.
    case disabled

    /// Lets the model decide, per request, whether and how deeply to think.
    case adaptive
}

// MARK: - ReasoningEffort

/// The `reasoning_effort` parameter of OpenAI's GPT-5 family.
///
/// For reasoning models, sets how many tokens go into the thinking step — which is to say speed,
/// cost, and accuracy. Where `ThinkingMode` is an on/off switch, this is an independent,
/// OpenAI-specific grade of effort.
///
/// **Which values a model accepts differs by model.** Sending an unsupported value gets the request
/// rejected (`invalid_request_error`), so check with `GPTModel.supports(_:)` before sending.
public enum ReasoningEffort: String, Sendable, Equatable, CaseIterable {
    /// No thinking at all. Fastest and cheapest.
    ///
    /// - Note: Easily confused with `Optional.none` when compared against a `ReasoningEffort?`.
    ///   Spell out the type as `== ReasoningEffort.none`.
    case none
    /// Minimises thinking tokens.
    ///
    /// - Warning: **Current models do not accept this.** It was replaced by `none` in GPT-5.3.
    ///   Kept for older models: the o-series and GPT-5 / 5.1 / 5.2.
    case minimal
    /// Shallow thinking. Suited to triage, small edits, and light multi-step tool routing.
    case low
    /// The default, and the safe choice for general workloads.
    case medium
    /// Deep multi-step thinking. Suited to planning and involved analysis.
    case high
    /// Deeper still than `high`.
    case xhigh
    /// The deepest thinking available. GPT-5.6 family only.
    case max
}
