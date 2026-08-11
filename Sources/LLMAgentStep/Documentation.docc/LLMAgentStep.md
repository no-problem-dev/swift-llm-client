# ``LLMAgentStep``

One step of an agent loop — the request, the response and the stream between them. The loop itself is yours.

## Overview

An agent loop is a small amount of policy wrapped around a lot of transport. `LLMAgentStep`
takes the transport half: given messages, tools and a model, it performs a single
request/response step and reports what came back. Loop control, tool dispatch and history
management stay outside, in an agent runtime.

Keeping the step separate is what lets a runtime pause for confirmation, run tools in a sandbox,
enforce a step budget, or replay a turn — none of which is possible if the loop is buried in the
client.

**AgentCapableClient** defines `executeAgentStep` and `streamAgentStep`. A provider that
implements only the former still conforms: `streamAgentStep` has a default implementation that
calls `executeAgentStep` and emits its result as a single `.completed` event. That shim is
convenient, but it means a stream from such a provider yields no `.delta` events at all — the
call looks streaming and behaves as a blocking request. Check the provider before you build UI
that depends on incremental output.

**StreamingAgentEvent** is what a stream yields. `.delta(StreamDelta)` carries incremental text
and reasoning output as it arrives; `.completed(LLMResponse)` carries the finished response,
including any tool calls and the usage figures for the step. Only `.completed` has the whole
picture — accumulate deltas for display, but drive loop decisions from the completed response.

```swift
import LLMAgentStep
import LLMTool

let stream = client.streamAgentStep(
    messages: messages,
    model: .claude(.sonnet),
    systemPrompt: systemPrompt,
    tools: tools,
    toolChoice: nil,
    responseSchema: nil,
    thinkingMode: .disabled,
    reasoningEffort: nil,
    maxTokens: nil,
    cachePolicy: .implicit
)

for try await event in stream {
    switch event {
    case .delta(let delta):
        // Show reasoning and text as they arrive.
        if case .textDelta(let text) = delta { print(text) }
    case .completed(let response):
        // Step finished. Tool calls here decide whether the loop continues.
        handleResponse(response)
    }
}
```

## Topics

### Agent steps

- ``AgentCapableClient``
- ``StreamingAgentEvent``
