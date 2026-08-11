# Module Layout

Choose the libraries to import, and understand how they depend on one another.

## Overview

The package ships nine libraries rather than one, so an app that only needs a chat completion
does not compile a video-generation catalog, a macro plugin, or a `UIKit` bridge. Every library
is additive: importing more never changes the behaviour of what you already imported.

`LLMCore` sits at the bottom and depends on nothing. Everything else depends on it, directly or
transitively, and no library depends sideways on a sibling that is not listed below.

| Library | What it gives you | Depends on |
|---|---|---|
| `LLMCore` | Messages, multimodal content, model profiles, token usage, cost | — |
| `LLMProviderCompat` | Pre-flight checks for per-provider media support | `LLMCore` |
| `LLMMediaKit` | `UIImage` / `NSImage` / `AVAudioPlayer` bridges for generated media | `LLMCore` |
| `LLMClient` | Structured output, JSON Schema, prompt DSL, model catalogs, streaming | `LLMCore`, `LLMProviderCompat` |
| `LLMTool` | `@Tool` macro, `ToolSet`, single-shot function calling | `LLMClient` |
| `LLMChat` | Multi-turn conversation state and history | `LLMClient` |
| `LLMDynamicStructured` | Compatibility re-export of `LLMClient` | `LLMClient` |
| `LLMAgentStep` | One step of an agent loop, with streaming events | `LLMClient`, `LLMTool` |
| `LLMContext` | Live context-window occupancy and per-segment breakdown | `LLMClient`, `LLMTool` |

`LLMMediaKit` is a leaf: nothing depends on it, so linking it is always a choice and never a
consequence.

## Which ones do I need?

**Import `LLMClient` if you want a typed answer.** It carries the `@Structured` macro, the JSON
Schema layer that turns your type into a provider-acceptable schema, the `SystemPrompt` DSL, and
the per-provider model catalogs. It re-exports `LLMCore` and `LLMProviderCompat`, so one import
gets you the domain types and the media compatibility checks as well.

**Add `LLMTool` if the model has to call your code.** It builds on `LLMClient` and reuses its
schema machinery, so `@Tool` argument constraints go through the same provider adaptation as
`@Structured` fields. Adding it to a target that already links `LLMClient` costs you nothing new
at the bottom of the stack.

**Add `LLMAgentStep` only if you are writing the loop.** It defines a single request/response
step and the streaming events for it. Loop control, tool dispatch and history bookkeeping are
the runtime's job, not this package's — which is why the step and the loop are separated.

**Add `LLMChat` for multi-turn state.** Its value is that a turn hands back both the decoded
result and the assistant message to append, so history stays consistent without the caller
reassembling it.

**Add `LLMContext` when you need to show how full the window is.** Live occupancy is free — it
comes from the usage numbers you already received. The per-segment breakdown is not: it costs
extra token-counting calls, so it is computed on demand and cached.

**`LLMMediaKit` is the only truly optional one.** It exists so that `UIKit` and `AVFoundation`
stay out of the domain layer; add it when you need to display or play what the model produced.
`LLMProviderCompat` you already have — `LLMClient` re-exports it — so its media checks are
available without a second import.

## Where providers come from

This package contains no networking and no API keys. It defines the protocols
— ``StructuredLLMClient``, ``LLMProvider``, `ToolCallableClient`, `AgentCapableClient`,
`ChatCapableClient` — and concrete provider packages conform to them. That boundary is the whole
point: call sites are written against the protocol, so switching provider is a change of one
binding, not a rewrite.

The layering is also why `LLMCore` holds no provider-specific logic. Facts that differ per
provider — cache TTLs, accepted MIME types, schema keywords that must be stripped — are recorded
where they are acted on, not in the shared primitives.
