import Foundation

// MARK: - Claude Models

/// The Anthropic Claude models.
///
/// A model is named either by alias, which follows whatever snapshot Anthropic currently points it
/// at, or by a fixed version that never moves under you.
///
/// ## Aliases
/// ```swift
/// let client = AnthropicClient(apiKey: "...")
/// let result: UserInfo = try await client.generate(
///     input: "...",
///     model: .sonnet  // Whichever Sonnet is current.
/// )
/// ```
///
/// ## Pinned versions
/// ```swift
/// let result: UserInfo = try await client.generate(
///     input: "...",
///     model: .opus4_6_version("20260210")  // One specific snapshot.
/// )
/// ```
///
/// ## Custom identifiers
/// ```swift
/// let result: UserInfo = try await client.generate(
///     input: "...",
///     model: .custom("claude-opus-4-6-20260210")
/// )
/// ```
public enum ClaudeModel: Sendable, Equatable {
    // MARK: - Aliases (recommended)

    /// The current Opus, the top of the range. It resolves to Opus 4.8 and moves as newer ones ship.
    case opus

    /// The current Sonnet, the balanced tier. It resolves to Sonnet 4.6 and moves with the family.
    case sonnet

    /// The current Haiku, the fast and cheap tier. It resolves to Haiku 4.5 and moves with it.
    case haiku

    // MARK: - Dateless Snapshots (4.6 generation onward)

    /// Claude Opus 4.8. The identifier carries no date but still names one fixed snapshot.
    case opus4_8

    /// Claude Opus 4.7. The identifier carries no date but still names one fixed snapshot.
    case opus4_7

    /// Claude Opus 4.6, pinned by a dateless identifier.
    case opus4_6

    /// Claude Sonnet 4.6, pinned by a dateless identifier.
    case sonnet4_6

    // MARK: - Aliased Versions (4.5 generation, dated under the hood)

    /// Claude Opus 4.5 alias
    case opus4_5

    /// Claude Sonnet 4.5 alias
    case sonnet4_5

    /// Claude Haiku 4.5 alias
    case haiku4_5

    // MARK: - Fixed Versions

    case opus4_8_version(String)
    case opus4_7_version(String)
    case opus4_6_version(String)
    case sonnet4_6_version(String)
    case opus4_5_version(String)
    case sonnet4_5_version(String)
    case haiku4_5_version(String)
    case opus4_1_version(String)
    case opus4_version(String)
    case sonnet4_version(String)

    // MARK: - Custom

    case custom(String)

    // MARK: - Model ID

    /// Whether the model accepts Extended Thinking.
    ///
    /// Opus 4.7 and 4.8 do Adaptive Thinking instead and take no Extended Thinking, and neither
    /// does Haiku — which means the `opus` and `haiku` aliases answer false while `sonnet` answers
    /// true. A custom identifier is assumed to support it.
    public var supportsExtendedThinking: Bool {
        switch self {
        case .opus, .opus4_8, .opus4_8_version, .opus4_7, .opus4_7_version:
            return false
        case .haiku, .haiku4_5, .haiku4_5_version:
            return false
        case .sonnet, .sonnet4_6, .sonnet4_6_version,
             .opus4_6, .opus4_6_version,
             .opus4_5, .opus4_5_version,
             .sonnet4_5, .sonnet4_5_version,
             .opus4_1_version,
             .opus4_version, .sonnet4_version:
            return true
        case .custom:
            return true
        }
    }

    /// The identifier sent to the API, with each alias already resolved to the model it names.
    public var id: String {
        switch self {
        case .opus, .opus4_8:
            return "claude-opus-4-8"
        case .opus4_7:
            return "claude-opus-4-7"
        case .sonnet, .sonnet4_6:
            return "claude-sonnet-4-6"
        case .haiku, .haiku4_5:
            return "claude-haiku-4-5"
        case .opus4_6:
            return "claude-opus-4-6"
        case .opus4_5:
            return "claude-opus-4-5"
        case .sonnet4_5:
            return "claude-sonnet-4-5"
        case .opus4_8_version(let version):
            return "claude-opus-4-8-\(version)"
        case .opus4_7_version(let version):
            return "claude-opus-4-7-\(version)"
        case .opus4_6_version(let version):
            return "claude-opus-4-6-\(version)"
        case .sonnet4_6_version(let version):
            return "claude-sonnet-4-6-\(version)"
        case .opus4_5_version(let version):
            return "claude-opus-4-5-\(version)"
        case .sonnet4_5_version(let version):
            return "claude-sonnet-4-5-\(version)"
        case .haiku4_5_version(let version):
            return "claude-haiku-4-5-\(version)"
        case .opus4_1_version(let version):
            return "claude-opus-4-1-\(version)"
        case .opus4_version(let version):
            return "claude-opus-4-\(version)"
        case .sonnet4_version(let version):
            return "claude-sonnet-4-\(version)"
        case .custom(let id):
            return id
        }
    }
}

// MARK: - Preset

extension ClaudeModel {
    public enum Preset: String, CaseIterable, Identifiable, Codable, Sendable {
        case opus = "opus"
        case sonnet = "sonnet"
        case haiku = "haiku"

        public var id: String { rawValue }

        public var model: ClaudeModel {
            switch self {
            case .opus: return .opus
            case .sonnet: return .sonnet
            case .haiku: return .haiku
            }
        }

        public var displayName: String {
            switch self {
            case .opus: return "Claude Opus 4.8"
            case .sonnet: return "Claude Sonnet 4.6"
            case .haiku: return "Claude Haiku 4.5"
            }
        }

        public var shortName: String {
            switch self {
            case .opus: return "Opus"
            case .sonnet: return "Sonnet"
            case .haiku: return "Haiku"
            }
        }

        public var profile: ModelProfile {
            switch self {
            case .opus:
                return ModelProfile(
                    summary: "Top performance: best for complex reasoning and code generation",
                    modelFamily: "Claude",
                    description: "Claude Opus 4.8 is Anthropic's current flagship. It excels at complex multi-step reasoning, advanced code generation, and agent workflows. It takes a 1M-token context window and produces up to 128K of output. Adaptive Thinking allocates compute automatically according to how hard the work is. It uses a new tokenizer, so the same text can come to up to 35% more tokens than on 4.6.",
                    contextWindow: 1_000_000,
                    maxOutputTokens: 128_000,
                    knowledgeCutoff: "2026-01",
                    strengths: ["Complex reasoning", "Code generation", "Building agents", "Adaptive Thinking", "Very large context"],
                    bestFor: ["Agent workflows", "Complex analysis and reasoning", "Long-form code generation"],
                    toolCallSupport: .excellent,
                    japaneseSupport: .excellent,
                    modalities: [.text, .vision, .code],
                    pricing: .flat(
                        inputPerMTok: 5,
                        outputPerMTok: 25,
                        cacheReadPerMTok: 0.50,
                        cacheWriteShortPerMTok: 6.25,
                        cacheWriteLongPerMTok: 10
                    )
                )
            case .sonnet:
                return ModelProfile(
                    summary: "Balanced: the best trade-off of speed and quality",
                    modelFamily: "Claude",
                    description: "Claude Sonnet 4.6 strikes the best balance of speed and intelligence. It takes a 1M-token context window and supports both Extended Thinking and Adaptive Thinking.",
                    contextWindow: 1_000_000,
                    maxOutputTokens: 64_000,
                    knowledgeCutoff: "2025-08",
                    strengths: ["Speed and quality balance", "Coding", "Very large context", "Extended Thinking"],
                    bestFor: ["High-throughput analysis", "Coding tasks", "Cost-efficient general tasks"],
                    toolCallSupport: .excellent,
                    japaneseSupport: .excellent,
                    modalities: [.text, .vision, .code],
                    pricing: .flat(
                        inputPerMTok: 3,
                        outputPerMTok: 15,
                        cacheReadPerMTok: 0.30,
                        cacheWriteShortPerMTok: 3.75,
                        cacheWriteLongPerMTok: 6
                    )
                )
            case .haiku:
                return ModelProfile(
                    summary: "Fast and inexpensive: best for light tasks",
                    modelFamily: "Claude",
                    description: "Claude Haiku 4.5 is the fastest Claude model, offering near-frontier intelligence at low cost. It suits real-time chat and high-volume work.",
                    contextWindow: 200_000,
                    maxOutputTokens: 64_000,
                    knowledgeCutoff: "2025-02",
                    strengths: ["Fast responses", "Low cost", "High-volume work"],
                    bestFor: ["Real-time chat", "High-volume batches", "Cost-sensitive apps"],
                    toolCallSupport: .excellent,
                    japaneseSupport: .excellent,
                    modalities: [.text, .vision, .code],
                    pricing: .flat(
                        inputPerMTok: 1,
                        outputPerMTok: 5,
                        cacheReadPerMTok: 0.10,
                        cacheWriteShortPerMTok: 1.25,
                        cacheWriteLongPerMTok: 2
                    )
                )
            }
        }
    }
}
