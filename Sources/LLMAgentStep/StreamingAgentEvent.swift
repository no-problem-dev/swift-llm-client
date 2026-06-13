import LLMClient

/// An event from a streamed agent step.
///
/// Part of the agent-step contract (`AgentCapableClient.streamAgentStep`), kept
/// out of the pure model-access layer:
/// - `.delta`: an in-flight thinking/text delta.
/// - `.completed`: the full response once the step finishes.
public enum StreamingAgentEvent: Sendable {
    case delta(StreamDelta)
    case completed(LLMResponse)
}
