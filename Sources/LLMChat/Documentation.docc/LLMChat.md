# ``LLMChat``

Multi-turn conversation that keeps structured output, without hand-assembling the history.

## Overview

A chat completion API is stateless: the model sees only the messages you send, so continuity is
entirely your bookkeeping. Doing that by hand around structured output is where it usually goes
wrong — you get a decoded value back, but not the assistant turn that produced it, and the next
request silently loses a turn.

`LLMChat` closes that gap.

**ChatCapableClient** extends `StructuredLLMClient` with `chat(messages:model:)`. Where
`generate` returns only the decoded value, `chat` returns a ``ChatResponse`` holding both the
`result` and the `assistantMessage` to append. Append it, and the history stays consistent
without you reconstructing what the model said.

**ConversationHistory** is an actor that owns the message array and the running token total.
Being an actor makes concurrent appends safe from any task, and it means every read is `await` —
a snapshot from `getMessages()` is a value, so a turn started with it is unaffected by appends
that land while the request is in flight.

Subscribe to `eventStream` for ``ConversationEvent`` values covering user messages, assistant
replies, tool calls and errors. Running totals arrive there too, as `usageUpdated` — note that
the total tracks input and output tokens only, so cache and reasoning breakdowns have to come
from the per-turn `usage` on each ``ChatResponse``.

```swift
import LLMChat

let history = ConversationHistory()

Task {
    for await event in history.eventStream {
        if case .usageUpdated(let usage) = event {
            print("cumulative tokens: \(usage.totalTokens)")
        }
    }
}

await history.append(.user("What is an Optional in Swift?"))
let first: ChatResponse<Explanation> = try await client.chat(
    messages: await history.getMessages(),
    model: .claude(.sonnet)
)
await history.append(first.assistantMessage)

await history.append(.user("Show me optional chaining."))
let second: ChatResponse<Explanation> = try await client.chat(
    messages: await history.getMessages(),
    model: .claude(.sonnet)
)
await history.append(second.assistantMessage)

print(first.result.summary)
```

Nothing here truncates the history for you. Every turn re-sends the whole conversation, so input
tokens grow with the transcript; use `LLMContext` to watch the window and decide when to
summarise or drop older turns.

## Topics

### Clients

- ``ChatCapableClient``
- ``ChatResponse``

### History

- ``ConversationHistory``
- ``ConversationHistoryProtocol``
- ``ConversationEvent``
