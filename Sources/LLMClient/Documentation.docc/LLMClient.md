# ``LLMClient``

Talk to Claude, GPT, Gemini and the rest through one API, and get answers back as your own Swift types.

## Overview

`LLMClient` is the layer you write application code against. It takes a Swift type, derives a
JSON Schema the target provider will actually accept, sends the request through whichever
provider implementation you bound, and decodes the reply back into that type. Swapping provider
changes the model argument and nothing else.

The package is split into nine libraries so you only compile what you use; see
<doc:ModuleLayout> for what each one holds and which to import. If you are starting from
nothing, <doc:GettingStarted> walks the first request end to end.

Three things live in this module specifically.

**Structured output.** Annotating a type with `@Structured` synthesises its JSON Schema at
compile time, injects it into the request, and decodes the response. The field descriptions you
write are what the model sees, so they are prompt engineering, not comments.

```swift
@Structured("A task extracted from free text")
struct TaskInfo {
    @StructuredField("Short imperative title")
    var title: String

    @StructuredField("Priority", .enum(["low", "medium", "high"]))
    var priority: String

    @StructuredField("Due date, ISO 8601", .format(.date))
    var dueDate: String?
}
```

Providers disagree about which schema keywords they accept. ``ProviderSchemaAdapter`` strips the
ones a given provider rejects and reports them in ``SchemaAdaptationResult``, so a constraint
that cannot be enforced by the schema can be restated in the prompt instead of being silently
lost.

**The prompt DSL.** ``SystemPrompt`` composes ``PromptComponent`` values into XML-tagged text.
The tag names and the emitted order are part of the contract — reordering components changes
what the model sees.

**The provider seam.** ``LLMProvider`` and ``StructuredLLMClient`` are the protocols a provider
package conforms to. This module ships no networking and holds no credentials.

Token accounting is a choice you make at the call site: `generate` returns only the decoded
value, while `generateWithUsage` also hands back the `TokenUsage` for the call. Reach for the
second one whenever you need to bill, cap or display cost — the numbers cannot be recovered
afterwards.

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:ModuleLayout>

### Clients and providers

- ``StructuredLLMClient``
- ``LLMProvider``
- ``LLMRequest``
- ``GenerationResult``
- ``LLMModel``

### Input

- ``LLMInput``
- ``LLMInputProtocol``

### Structured output

- ``StructuredProtocol``
- ``JSONSchema``
- ``JSONSchemaType``
- ``JSONSchemaError``
- ``NamedSchema``
- ``FieldConstraint``

### Provider schema adaptation

- ``ProviderSchemaAdapter``
- ``SchemaAdaptationResult``
- ``RemovedConstraint``
- ``ConstraintType``
- ``ConstraintValue``

### Prompt DSL

- ``SystemPrompt``
- ``PromptComponent``
- ``SystemPromptMetadata``
- ``SystemPromptBuilder``

### Streaming and caching

- ``StreamDelta``
- ``ThinkingMode``
- ``ReasoningEffort``
- ``PromptCachePolicy``

### Macros

- ``Structured(_:)``
- ``StructuredField(_:_:)``
- ``StructuredEnum(_:)``
- ``StructuredCase(_:)``

### Utilities

- ``Box``
