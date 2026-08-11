# Changelog

All notable changes to this project are recorded in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Raised the swift-structured-data pin to 3.0.0. That release makes the YAML parser reject
  constructs it does not model instead of silently dropping them; nothing in this package's own
  API changes.


Nothing.

## [3.13.0] - 2026-08-06

Corrects `ReasoningEffort` per model. The four steps — minimal / low / medium / high — no longer
matched what the providers accept, and sending `minimal` to a GPT-5.6 model had the whole request
rejected with "'minimal' is not supported". Every model and every step was checked against the
live API.

### Added
- **`none`, `xhigh` and `max` efforts.** `minimal` was replaced by `none` from GPT-5.1 onwards, and
  is kept for the GPT-5.0 generation.
- **`supports(_:)`**, which decides acceptance one step at a time.
- **`clamped(_:)`**, which moves an unsupported value to the nearest step the model does accept
  rather than dropping it: `max` → `xhigh` → `high`, and `none` → `minimal` → `low`.

### Deprecated
- `supportsMinimalReasoningEffort`, which only ever looked at `minimal` and could not express the
  differences between the other steps.

## [3.12.0] - 2026-08-06

Takes retired models off `Preset` and adds the current generation. The Gemini 2.5 family had been
closed to new users, so choosing one failed the whole conversation with a 404 — "no longer available
to new users" — while it was still on the list to choose from.

### Added
- **Gemini**: `gemini-3.6-flash` (the current Flash: same input price as 3.5, output down from $9 to
  $7.50) and `gemini-3.5-flash-lite`.
- **OpenAI**: the `gpt-5.6` family — Sol, Terra and Luna — now the mainstay of `Preset`. Past 272K
  tokens 5.6 charges double for input and 1.5× for output, which is expressed through `tiers`.
- **`GeminiModel.isRetired`**, to tell a retired model from a current one.

### Changed
- `Preset` is the list a user chooses from, so it now carries only models still on offer: the three
  Gemini 2.5 entries are gone, and 5.5 / 5.4 come off it too, since 5.6 supersedes them.
- The `GeminiModel` and `GPTModel` cases themselves stay, so a stored id still reads back. Falling
  through to `custom` would lose both the display name and the profile.

Prices, context sizes and cutoffs come from each provider's own pricing and model pages, and all 12
models were called for real and answered 200. A regression test holds retired models out of `Preset`.

## [3.11.0] - 2026-07-30

### Added
- **`TranscriptAwareTool` (LLMTool)**: gives a tool the conversation as it stands at the moment it
  runs — the counterpart of LangGraph's `ToolRuntime.state`, ADK's `tool_context.session` and
  Strands' `ctx.agent.messages`. The live message list the loop runtime holds, including tool
  results already completed within the same run, is passed only to tools that conform. It travels
  by value, so a tool cannot alter the loop's history.
- **`ToolSet.execute(toolNamed:with:transcript:)`**. Tools that do not conform fall back to the
  ordinary path, so a loop runtime can always call this one.

Trimming the trailing assistant message that carries the in-flight tool call is the tool's own
responsibility, since only the tool knows its own name — all three official adapters do it in their
adapter layer as well.

## [3.10.1] - 2026-07-30

### Changed (breaking)
- `LLMResponse.generatedAudioFiles` → `generatedAudio`, so it sits alongside `generatedImages` and
  `firstGeneratedAudio`.
- `ToolResultConvertible.toToolResult()` → `asToolResult()`. A `to-` prefix breaks the API Design
  Guidelines; a conversion is spelled `as-`.

Both renames were contained inside llm-client, with no outside consumers.

### Changed
- Widened the accepted `swift-structured-data` range to `1.3.0..<3.0.0`. The only breaking change in
  2.0.0 was renaming `StructuredValue.encoding` to `encoded`, which this package does not use, so it
  fits both series.

## [3.10.0] - 2026-07-19

Documentation and tests, plus one widening of visibility.

### Added
- Landing pages and `GettingStarted` articles in the `LLMClient` and `LLMTool` DocC catalogs.
- Real tests for the `LLMMacros` expansions and for `LLMChat` behaviour, replacing placeholders.

### Changed
- `ProviderSchemaAdapter`'s helpers are now public, so an adapter can be extended from outside.
- DocC builds every library into one combined document, with the package overview injected into the
  combined root.
- README is English primary with a Japanese counterpart (`README.ja.md`); the old `README_EN.md` is
  gone, and the doc comments and DocC catalogs were rewritten throughout.
- Corrected API mistakes in the README: `@LLMTool` should have read `@Tool`, and the module table
  listed four modules where there are seven.
- Resynced the standard workflows from the SSOT templates (tests and release-on-tag); the old
  auto-release workflow is gone.

## [3.9.0] - 2026-06-15

### Added
- **`JSONSchema` nullable support**: a property can be written as a union with null
  (`type: ["<type>", "null"]`). OpenAI's strict mode represents an optional property by keeping it in
  `required` and allowing null, and this is how that shape is expressed. `Codable` converts between
  the single-type and null-union forms in both directions.

## [3.8.0] - 2026-06-14

Adds the foundation for context window measurement. Provides the pure domain logic for
showing, per host and per sub-agent (A2), how much of the window is occupied and by what
(system prompt / tool definitions / conversation history).

### Added
- **`ContextOccupancy` (LLMCore)**: a pure value type that computes live occupancy
  (used / free / cached / fresh / occupancy ratio) from `TokenUsage` plus the window size.
  Provides initialization from the `usage`, `used`, `ModelProfile`, and ACP `usage_update` paths.
  When `contextWindow == nil`, free and the ratio are `nil`
  (the occupancy ratio is not fabricated = silent fallback eliminated).
- **`TokenCounting` protocol (LLMTool)**: the port for the `count_tokens` capability (with `modelID`).
  Implementations are supplied by each provider adapter (swift-llm-cloud).
- **`LLMContext` target (new product)**: `SegmentBreakdownEngine`, which computes the
  per-category breakdown by **difference subtraction** (canceling out the per-request wrapper,
  structurally avoiding the over-counting that comes from summing standalone counts);
  the incremental recomputation `BreakdownCache`; the host/A2 aggregate `AgentContextTracker`;
  the display transform `ContextBarLayout`; and `ContextReport` / `SegmentBreakdown` / `ContextSegment`.

## [3.7.0] - 2026-06-14

Groundwork for multimodal. The media layer is redesigned along hexagonal principles.
It contains breaking changes, but by operational policy it ships as a minor version.

### Added
- **`DocumentContent` (PDF / plain-text input)**: adds the `MessageContent.document` case,
  `DocumentMediaType` (pdf/plainText), and `LLMMessage.user(_:document:)` / `documents`.
  PDF input, which could not be expressed at the type level until now, is supported.
- **Module split**: `LLMCore` (pure domain, Foundation only) / `LLMProviderCompat`
  (the provider compatibility matrix) / `LLMMediaKit` (platform features such as UIImage
  conversion) are published as independent products. `LLMClient` keeps the existing
  `import LLMClient` working via `@_exported import`.

### Changed (breaking)
- **Removed provider knowledge from the domain value types**: deleted `ImageContent.detail` (OpenAI-only).
  Moved `validate(for:)` on `ImageContent/AudioContent/VideoContent`, `MediaType.isSupported(by:)`,
  and `ProviderType` to `MediaCompatibility` (LLMProviderCompat).
- **Removed platform dependencies from the domain value types**: moved `GeneratedImage/Audio/Video`'s
  `uiImage`/`nsImage`/`cgImage`/`imageSize`/`audioPlayer`/`downloadData()` to `LLMMediaKit`.
  The core value types are now Foundation only.
- Removed `.notSupportedByProvider` and `validateSupport(_:for:)` from `MediaError`
  (moved to `ProviderCompatibilityError` / `MediaCompatibility`). Fixed `errorDomain`.

### Internal
- Split the god file `LLMProvider.swift` into `LLMResponse`/`LLMMessage`/`LLMError`.
- Swept out the remnants of the old package name `swift-llm-structured-outputs`.

## [3.5.0] - 2026-06-08

### Added
- **Schema-conforming coercion of tool arguments**: adds `JSONSchema.coerceArguments(_:)`, and
  `ToolSet.execute(toolNamed:with:)` corrects the argument JSON against the tool's `inputSchema`.
  Small local LLMs sometimes emit numbers and booleans as strings (e.g. `{"max_results":"10"}`);
  those are converted only on fields whose schema demands `integer` / `number` / `boolean`,
  which prevents type-mismatch errors from the strict `JSONDecoder`. Well-formed arguments
  and `string` fields are left unchanged. Provider-independent, so it applies to every tool

## [3.4.2] - 2026-06-08

### Changed
- Relaxed the accepted swift-syntax range from `from: 602.0.0` to `600.0.0..<604.0.0`,
  so that it resolves in the same dependency graph as mlx-swift-lm 3.31.3
  (which requires swift-syntax 600..<601) — needed for remote consumption of swift-llm-local 2.x

## [1.0.0] - 2026-02-23

### Added
- Initial release
- **LLMClient** - provider-agnostic LLM client protocol
- **LLMTool** - Swift Macro based tool definitions
- **LLMChat** - chat message management
- **LLMDynamicStructured** - dynamic structured output

[Unreleased]: https://github.com/no-problem-dev/swift-llm-client/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/no-problem-dev/swift-llm-client/releases/tag/v1.0.0
