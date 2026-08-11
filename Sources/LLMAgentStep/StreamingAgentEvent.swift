import LLMClient

/// What a streamed agent step emits: fragments as they are produced, then the finished response.
///
/// Part of the step contract of `AgentCapableClient`, which is why it sits above the plain
/// model-access layer rather than inside it.
public enum StreamingAgentEvent: Sendable {
    /// A fragment of thinking or text just produced. Optional: a provider without native streaming
    /// emits none of these.
    case delta(StreamDelta)

    /// The finished response, emitted exactly once and always last.
    ///
    /// The only place tool calls, token usage, and the stop reason appear — none of them stream —
    /// so this event has to be handled even by a caller that renders every delta.
    case completed(LLMResponse)
}
