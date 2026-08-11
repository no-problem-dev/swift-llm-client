# Changelog

All notable changes to this project are recorded in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Nothing.

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
