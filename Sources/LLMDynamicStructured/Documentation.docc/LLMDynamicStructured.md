# ``LLMDynamicStructured``

A compatibility re-export of LLMClient, kept so older targets keep building.

## Overview

Structured output used to live in its own library. It was folded into `LLMClient`, and this
library remains as `@_exported import LLMClient` and nothing else. It defines no types of its
own — every symbol you get from it belongs to `LLMClient`, which is why its documentation lives
there.

A target that depends on this library needs no source changes. New code should depend on
`LLMClient` directly.

```swift
// Still works.
import LLMDynamicStructured

// Prefer this.
import LLMClient

@Structured("A task")
struct TaskInfo {
    @StructuredField("Title")
    var title: String
}
```
