# ``LLMCore``

The primitives every other library in the package is built on: messages, media, model profiles, tokens and cost.

## Overview

`LLMCore` depends on nothing and knows about no provider. It holds the types that would
otherwise have to be redefined in every layer above it, and it holds them in a form that is the
same whichever provider you end up talking to.

That neutrality has one deliberate exception, documented on the types themselves: where
providers report the *same* quantity differently, `LLMCore` fixes a single normalised meaning
and makes the provider adapter responsible for converting to it.

**Messages and responses.** `LLMMessage` carries a user, assistant or tool turn, with optional
multimodal attachments. `LLMResponse` bundles what came back — text, tool calls and usage — into
one value. `ToolResultContent` distinguishes a successful tool result from a failed one, so a
tool error can be handed back to the model instead of thrown at the caller.

**Multimodal input.** `ImageContent`, `AudioContent`, `VideoContent` and `DocumentContent` each
wrap a `MediaSource`, which supplies bytes from base64, a URL, a file path or a
previously-uploaded file reference. Not every provider accepts every source kind; check with
`LLMProviderCompat` before sending rather than reading it off a failed request.

**Generated media.** `GeneratedImage`, `GeneratedAudio` and `GeneratedVideo` hold what a model
produced, described by `ImageOutputFormat`, `AudioOutputFormat` and `VideoOutputFormat`.
Conversion to `UIImage`, `NSImage` or `AVAudioPlayer` is deliberately not here — it lives in
`LLMMediaKit`, so this layer stays free of platform frameworks.

**Model profiles.** `ModelProfile` records the context window, the maximum output tokens, the
supported modalities, the level of tool-call support and the inference speed. This is what lets
a call site ask "will this request fit?" without a table of per-provider trivia.

**Tokens and cost.** `TokenUsage` is the normalised account of a request: input tokens are
cache-inclusive, output tokens include reasoning tokens, and the cache figures are subsets of
the input. Read its documentation before writing a provider adapter — getting this wrong makes
every downstream cost figure wrong. `CostCalculator` turns usage plus `Pricing` into `Money`,
whose currency is a type parameter so `Money<USD>` and `Money<JPY>` cannot be added by accident.

```swift
import LLMCore

let usage = TokenUsage(inputTokens: 1000, outputTokens: 500)
let pricing = Pricing.flat(inputPerMTok: 3.0, outputPerMTok: 15.0)
let cost: Money<USD> = CostCalculator.cost(of: usage, with: pricing)
```

**Errors.** `LLMError` covers the failures that are common across providers — network,
authentication, rate limiting, context overflow. Media-specific failures are `MediaError`.

## Topics

### Messages

- ``LLMMessage``
- ``LLMResponse``
- ``LLMError``
- ``ToolResultContent``

### Multimodal input

- ``ImageContent``
- ``AudioContent``
- ``VideoContent``
- ``DocumentContent``
- ``MediaSource``
- ``MediaContentProtocol``

### Media types

- ``ImageMediaType``
- ``AudioMediaType``
- ``VideoMediaType``
- ``DocumentMediaType``
- ``MediaType``
- ``MediaError``

### Generated media

- ``GeneratedImage``
- ``GeneratedAudio``
- ``GeneratedVideo``
- ``GeneratedMediaProtocol``
- ``ImageOutputFormat``
- ``AudioOutputFormat``
- ``VideoOutputFormat``
- ``OutputMediaFormat``

### Model profiles

- ``ModelProfile``
- ``Modality``
- ``InferenceSpeed``
- ``ToolCallSupport``
- ``LanguageSupport``
- ``SupportLevel``
- ``YearMonth``

### Tokens and cost

- ``TokenUsage``
- ``CacheTier``
- ``ContextOccupancy``
- ``CostCalculator``
- ``Money``
- ``CurrencyProtocol``
- ``USD``
- ``JPY``
- ``EUR``
- ``Pricing``
- ``PricingTier``
- ``ExchangeRate``

### Streaming

- ``makeCancellableStream(_:)``
