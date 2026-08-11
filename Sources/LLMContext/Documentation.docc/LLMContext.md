# ``LLMContext``

Track how full each agent's context window is, and break the usage down by what put it there.

## Overview

Two questions come up once an agent runs for more than a few turns: how close to the limit am I,
and what is taking up the room. They have very different costs, and `LLMContext` keeps them
apart deliberately.

**Occupancy is free.** Every response already carries a `TokenUsage`, and every model already
has a window size in its `ModelProfile`. `ContextOccupancy` is those two numbers divided, so it
can be updated on every turn without any extra API traffic.

**A breakdown is not free.** Attributing tokens to the system prompt, the tool definitions and
the message history requires measuring each part, which means extra token-counting calls. So it
is computed on demand rather than continuously, and cached so that a turn which only appended a
message does not force the system prompt and tool definitions to be measured again.

**AgentContextTracker** holds a ``ContextReport`` per agent, keyed by an agent identifier, so a
host agent and its sub-agents are tracked separately. It is `@MainActor` because its consumer is
a SwiftUI view: record after each response, and observe the reports directly.

**ContextReport** exposes both figures: `occupancy` is always current, `breakdown` is whatever
was last computed. Call `refreshBreakdown` when a view actually needs the detail — not on every
turn.

**SegmentBreakdown** splits the window into ``ContextSegment`` values for the system prompt,
tool definitions and message history. ``ContextBarLayout`` turns those into proportional
segments for a progress bar, so the UI does not do arithmetic on token counts.

```swift
import LLMContext
import LLMCore

let tracker = AgentContextTracker(counter: tokenCounter)

// After each API response.
tracker.record(
    agentID: "host",
    usage: response.usage,
    profile: modelProfile
)

if let report = tracker.reports["host"] {
    let occupancy = report.occupancy
    print("used \(occupancy.used) of \(occupancy.windowSize ?? 0)")
}
```

## Topics

### Tracking

- ``AgentContextTracker``
- ``ContextReport``

### Breakdown

- ``ContextSegment``
- ``SegmentBreakdown``
- ``SegmentBreakdownEngine``
- ``ToolGroup``
- ``BreakdownCache``

### Presentation

- ``ContextBarLayout``
- ``ContextBarSegment``
