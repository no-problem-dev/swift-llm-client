import Foundation

// MARK: - GPT Models

/// The OpenAI GPT models.
///
/// This type is an **address**: it says which model is meant and nothing else. Cases for models
/// OpenAI has withdrawn stay here, because a stored identifier still has to read back.
/// **The list to put in front of a user is `Preset`**, which holds only what is still served.
public enum GPTModel: Sendable, Equatable {
    // MARK: - Aliases (recommended)

    case gpt5_6Sol
    case gpt5_6Terra
    case gpt5_6Luna
    case gpt5_5
    case gpt5_5Pro
    case gpt5_4
    case gpt5_4Mini
    case gpt5_4Nano
    case gpt5_4Pro
    case gpt5_3Codex
    case gpt5_2Codex
    case gpt5_2
    case gpt5_1
    case gpt5
    case gpt5Mini
    case gpt5Nano
    case gpt4_1
    case gpt4_1Mini
    case gpt4_1Nano
    case gpt4o
    case gpt4oMini
    case o1
    case o1Pro
    case o3
    case o3Pro
    case o3Mini
    case o4Mini

    // MARK: - Fixed Versions

    case gpt5_6Sol_version(String)
    case gpt5_6Terra_version(String)
    case gpt5_6Luna_version(String)
    case gpt5_5_version(String)
    case gpt5_4_version(String)
    case gpt5_4Mini_version(String)
    case gpt5_4Nano_version(String)
    case gpt5_2_version(String)
    case gpt5_2Codex_version(String)
    case gpt5_1_version(String)
    case gpt5_version(String)
    case gpt5Mini_version(String)
    case gpt5Nano_version(String)
    case gpt4_1_version(String)
    case gpt4_1Mini_version(String)
    case gpt4_1Nano_version(String)
    case gpt4o_version(String)
    case gpt4oMini_version(String)
    case o1_version(String)
    case o3_version(String)
    case o3Mini_version(String)
    case o4Mini_version(String)

    // MARK: - Custom

    case custom(String)

    /// Whether the model accepts a reasoning effort parameter.
    ///
    /// Sending `reasoning_effort` to a model that does not take it gets the whole request rejected.
    /// The o-series and every GPT-5 model accept it; the GPT-4 models do not, and a custom
    /// identifier is assumed not to.
    public var supportsReasoningEffort: Bool {
        switch self {
        case .o1, .o1Pro, .o3, .o3Pro, .o3Mini, .o4Mini,
             .o1_version, .o3_version, .o3Mini_version, .o4Mini_version:
            return true
        case .gpt5_6Sol, .gpt5_6Terra, .gpt5_6Luna,
             .gpt5_5, .gpt5_5Pro, .gpt5_4, .gpt5_4Mini, .gpt5_4Nano, .gpt5_4Pro,
             .gpt5_3Codex, .gpt5_2Codex, .gpt5_2, .gpt5_1, .gpt5, .gpt5Mini, .gpt5Nano,
             .gpt5_6Sol_version, .gpt5_6Terra_version, .gpt5_6Luna_version,
             .gpt5_5_version, .gpt5_4_version, .gpt5_4Mini_version, .gpt5_4Nano_version,
             .gpt5_2_version, .gpt5_2Codex_version, .gpt5_1_version, .gpt5_version,
             .gpt5Mini_version, .gpt5Nano_version:
            return true
        case .gpt4_1, .gpt4_1Mini, .gpt4_1Nano, .gpt4o, .gpt4oMini,
             .gpt4_1_version, .gpt4_1Mini_version, .gpt4_1Nano_version,
             .gpt4o_version, .gpt4oMini_version:
            return false
        case .custom:
            return false
        }
    }

    /// Whether the model accepts minimal reasoning effort.
    ///
    /// - Warning: This answers for one rung only. **New code should call `supports(_:)`**, because
    ///   models differ on more than minimal.
    @available(*, deprecated, message: "Use supports(_:) instead")
    public var supportsMinimalReasoningEffort: Bool { supports(.minimal) }

    /// Moves an effort to the nearest rung this model accepts.
    ///
    /// An unsupported value gets the whole request rejected, so the effort is **nudged rather than
    /// dropped**. Ties at equal distance go to the weaker rung, and the result is nil when the model
    /// takes no reasoning effort at all.
    ///
    /// - `max` → `xhigh` → `high`, stepping down.
    /// - `none` → `minimal` → `low`, stepping up.
    public func clamped(_ effort: ReasoningEffort) -> ReasoningEffort? {
        guard supportsReasoningEffort else {
            return nil
        }
        // Weakest first; the search walks outward from the requested rung.
        let ladder: [ReasoningEffort] = [.none, .minimal, .low, .medium, .high, .xhigh, .max]
        guard let index = ladder.firstIndex(of: effort) else {
            return nil
        }
        if supports(effort) {
            return effort
        }
        // Take the weaker neighbour then the stronger one at each distance, and stop at the first
        // rung the model accepts.
        for distance in 1 ..< ladder.count {
            for candidate in [index - distance, index + distance] where ladder.indices.contains(candidate) {
                if supports(ladder[candidate]) {
                    return ladder[candidate]
                }
            }
        }
        return nil
    }

    /// Whether the model accepts this reasoning effort.
    ///
    /// Sending a rung the model does not take gets the request rejected with an
    /// `invalid_request_error`. Which rungs exist depends on the generation:
    ///
    /// | Generation | Accepted effort |
    /// |---|---|
    /// | GPT-5.6 family | none / low / medium / high / xhigh / **max** |
    /// | GPT-5.2 through 5.5 | none / low / medium / high / xhigh |
    /// | GPT-5.1 | none / low / medium / high |
    /// | GPT-5.0 family | **minimal** / low / medium / high |
    /// | o-series | low / medium / high |
    ///
    /// `minimal` gave way to `none` from GPT-5.1 onward.
    public func supports(_ effort: ReasoningEffort) -> Bool {
        guard supportsReasoningEffort else {
            return false
        }
        switch effort {
        case .low, .medium, .high:
            return true
        case .minimal:
            // GPT-5.0 family only; the o-series and 5.1 onward took none instead.
            switch self {
            case .gpt5, .gpt5Mini, .gpt5Nano,
                 .gpt5_version, .gpt5Mini_version, .gpt5Nano_version:
                return true
            default:
                return false
            }
        case .none:
            // GPT-5.1 onward; the o-series and the GPT-5.0 family reject it.
            switch self {
            case .o1, .o1Pro, .o3, .o3Pro, .o3Mini, .o4Mini,
                 .o1_version, .o3_version, .o3Mini_version, .o4Mini_version,
                 .gpt5, .gpt5Mini, .gpt5Nano,
                 .gpt5_version, .gpt5Mini_version, .gpt5Nano_version:
                return false
            default:
                return true
            }
        case .xhigh:
            // GPT-5.2 onward.
            switch self {
            case .gpt5_6Sol, .gpt5_6Terra, .gpt5_6Luna,
                 .gpt5_5, .gpt5_5Pro, .gpt5_4, .gpt5_4Mini, .gpt5_4Nano, .gpt5_4Pro,
                 .gpt5_3Codex, .gpt5_2Codex, .gpt5_2,
                 .gpt5_6Sol_version, .gpt5_6Terra_version, .gpt5_6Luna_version,
                 .gpt5_5_version, .gpt5_4_version, .gpt5_4Mini_version, .gpt5_4Nano_version,
                 .gpt5_2_version, .gpt5_2Codex_version:
                return true
            default:
                return false
            }
        case .max:
            // GPT-5.6 family only.
            switch self {
            case .gpt5_6Sol, .gpt5_6Terra, .gpt5_6Luna,
                 .gpt5_6Sol_version, .gpt5_6Terra_version, .gpt5_6Luna_version:
                return true
            default:
                return false
            }
        }
    }

    /// The identifier sent to the API.
    public var id: String {
        switch self {
        case .gpt5_6Sol: return "gpt-5.6-sol"
        case .gpt5_6Terra: return "gpt-5.6-terra"
        case .gpt5_6Luna: return "gpt-5.6-luna"
        case .gpt5_5: return "gpt-5.5"
        case .gpt5_5Pro: return "gpt-5.5-pro"
        case .gpt5_4: return "gpt-5.4"
        case .gpt5_4Mini: return "gpt-5.4-mini"
        case .gpt5_4Nano: return "gpt-5.4-nano"
        case .gpt5_4Pro: return "gpt-5.4-pro"
        case .gpt5_3Codex: return "gpt-5.3-codex"
        case .gpt5_2Codex: return "gpt-5.2-codex"
        case .gpt5_2: return "gpt-5.2"
        case .gpt5_1: return "gpt-5.1"
        case .gpt5: return "gpt-5"
        case .gpt5Mini: return "gpt-5-mini"
        case .gpt5Nano: return "gpt-5-nano"
        case .gpt4_1: return "gpt-4.1"
        case .gpt4_1Mini: return "gpt-4.1-mini"
        case .gpt4_1Nano: return "gpt-4.1-nano"
        case .gpt4o: return "gpt-4o"
        case .gpt4oMini: return "gpt-4o-mini"
        case .o1: return "o1"
        case .o1Pro: return "o1-pro"
        case .o3: return "o3"
        case .o3Pro: return "o3-pro"
        case .o3Mini: return "o3-mini"
        case .o4Mini: return "o4-mini"
        case .gpt5_6Sol_version(let v): return "gpt-5.6-sol-\(v)"
        case .gpt5_6Terra_version(let v): return "gpt-5.6-terra-\(v)"
        case .gpt5_6Luna_version(let v): return "gpt-5.6-luna-\(v)"
        case .gpt5_5_version(let v): return "gpt-5.5-\(v)"
        case .gpt5_4_version(let v): return "gpt-5.4-\(v)"
        case .gpt5_4Mini_version(let v): return "gpt-5.4-mini-\(v)"
        case .gpt5_4Nano_version(let v): return "gpt-5.4-nano-\(v)"
        case .gpt5_2_version(let v): return "gpt-5.2-\(v)"
        case .gpt5_2Codex_version(let v): return "gpt-5.2-codex-\(v)"
        case .gpt5_1_version(let v): return "gpt-5.1-\(v)"
        case .gpt5_version(let v): return "gpt-5-\(v)"
        case .gpt5Mini_version(let v): return "gpt-5-mini-\(v)"
        case .gpt5Nano_version(let v): return "gpt-5-nano-\(v)"
        case .gpt4_1_version(let v): return "gpt-4.1-\(v)"
        case .gpt4_1Mini_version(let v): return "gpt-4.1-mini-\(v)"
        case .gpt4_1Nano_version(let v): return "gpt-4.1-nano-\(v)"
        case .gpt4o_version(let v): return "gpt-4o-\(v)"
        case .gpt4oMini_version(let v): return "gpt-4o-mini-\(v)"
        case .o1_version(let v): return "o1-\(v)"
        case .o3_version(let v): return "o3-\(v)"
        case .o3Mini_version(let v): return "o3-mini-\(v)"
        case .o4Mini_version(let v): return "o4-mini-\(v)"
        case .custom(let id): return id
        }
    }
}

// MARK: - Preset

/// The models to put in front of a user.
///
/// **Only what is still served belongs here.** A withdrawn model comes out of this list while its
/// `GPTModel` case stays behind, so stored identifiers keep reading back. Leaving one here means a
/// user can pick it and the call comes back 404.
extension GPTModel {
    public enum Preset: String, CaseIterable, Identifiable, Codable, Sendable {
        case gpt5_6Sol = "gpt5_6Sol"
        case gpt5_6Terra = "gpt5_6Terra"
        case gpt5_6Luna = "gpt5_6Luna"
        case gpt5_3Codex = "gpt5_3Codex"
        case gpt5_4Mini = "gpt5_4Mini"
        case gpt5_4Nano = "gpt5_4Nano"

        public var id: String { rawValue }

        public var model: GPTModel {
            switch self {
            case .gpt5_6Sol: return .gpt5_6Sol
            case .gpt5_6Terra: return .gpt5_6Terra
            case .gpt5_6Luna: return .gpt5_6Luna
            case .gpt5_3Codex: return .gpt5_3Codex
            case .gpt5_4Mini: return .gpt5_4Mini
            case .gpt5_4Nano: return .gpt5_4Nano
            }
        }

        public var displayName: String {
            switch self {
            case .gpt5_6Sol: return "GPT-5.6 Sol"
            case .gpt5_6Terra: return "GPT-5.6 Terra"
            case .gpt5_6Luna: return "GPT-5.6 Luna"
            case .gpt5_3Codex: return "GPT-5.3 Codex"
            case .gpt5_4Mini: return "GPT-5.4 mini"
            case .gpt5_4Nano: return "GPT-5.4 nano"
            }
        }

        public var shortName: String {
            switch self {
            case .gpt5_6Sol: return "5.6 Sol"
            case .gpt5_6Terra: return "5.6 Terra"
            case .gpt5_6Luna: return "5.6 Luna"
            case .gpt5_3Codex: return "5.3 Codex"
            case .gpt5_4Mini: return "5.4 mini"
            case .gpt5_4Nano: return "5.4 nano"
            }
        }

        public var profile: ModelProfile {
            switch self {
            case .gpt5_6Sol:
                return ModelProfile(
                    summary: "The current flagship: the most complex reasoning and agent work",
                    modelFamily: "GPT",
                    description: "GPT-5.6 Sol is the frontier model of the GPT-5.6 family. With a context of up to 1.05M tokens, it suits advanced coding, multi-step planning, and tool use. Input past 272K is charged at 2x on input and 1.5x on output.",
                    contextWindow: 1_050_000,
                    maxOutputTokens: 128_000,
                    knowledgeCutoff: "2026-02",
                    strengths: ["Top-quality reasoning", "Multimodal", "Tool calling", "Agent performance"],
                    bestFor: ["Analysis needing top quality", "Critical agent tasks", "Advanced coding"],
                    toolCallSupport: .excellent,
                    japaneseSupport: .excellent,
                    modalities: [.text, .vision, .code],
                    pricing: Pricing(
                        tiers: [
                            PricingTier(upToInputTokens: 272_000, inputPerMTok: 5, outputPerMTok: 30),
                            PricingTier(upToInputTokens: nil, inputPerMTok: 10, outputPerMTok: 45),
                        ],
                        cacheReadPerMTok: 0.50
                    )
                )
            case .gpt5_6Terra:
                return ModelProfile(
                    summary: "Balanced: midway between intelligence and cost",
                    modelFamily: "GPT",
                    description: "GPT-5.6 Terra sits between Sol and Luna as the general-purpose model. At $2 / $12 it fits everyday coding, reasoning, and agent work. Input past 272K is charged at 2x on input and 1.5x on output.",
                    contextWindow: 1_050_000,
                    maxOutputTokens: 128_000,
                    knowledgeCutoff: "2026-02",
                    strengths: ["Versatility", "Cost efficiency", "Tool calling", "Adaptive reasoning"],
                    bestFor: ["General agents", "Mid-sized analysis", "Cost-sensitive production"],
                    toolCallSupport: .excellent,
                    japaneseSupport: .excellent,
                    modalities: [.text, .vision, .code],
                    pricing: Pricing(
                        tiers: [
                            PricingTier(upToInputTokens: 272_000, inputPerMTok: 2, outputPerMTok: 12),
                            PricingTier(upToInputTokens: nil, inputPerMTok: 4, outputPerMTok: 18),
                        ],
                        cacheReadPerMTok: 0.20
                    )
                )
            case .gpt5_6Luna:
                return ModelProfile(
                    summary: "Cheapest and highest throughput: for high-volume work",
                    modelFamily: "GPT",
                    description: "GPT-5.6 Luna is built for cost and volume. At $0.20 / $1.20 it still carries a 1.05M-token context, and it suits chat, classification, and light agent work. Input past 272K is charged at 2x on input and 1.5x on output.",
                    contextWindow: 1_050_000,
                    maxOutputTokens: 128_000,
                    knowledgeCutoff: "2026-02",
                    strengths: ["Lowest cost", "High throughput", "Low latency", "Tool calling"],
                    bestFor: ["High-volume batches", "Classification", "Chat", "Light agent work"],
                    toolCallSupport: .excellent,
                    japaneseSupport: .good,
                    modalities: [.text, .vision, .code],
                    pricing: Pricing(
                        tiers: [
                            PricingTier(upToInputTokens: 272_000, inputPerMTok: 0.20, outputPerMTok: 1.20),
                            PricingTier(upToInputTokens: nil, inputPerMTok: 0.40, outputPerMTok: 1.80),
                        ],
                        cacheReadPerMTok: 0.02
                    )
                )
            case .gpt5_3Codex:
                return ModelProfile(
                    summary: "Coding specialist: tuned for writing and fixing code",
                    modelFamily: "GPT",
                    description: "GPT-5.3 Codex is OpenAI's dedicated coding model. At $1.75 / $14 it is tuned for code generation, refactoring, code review, and debugging.",
                    contextWindow: 400_000,
                    maxOutputTokens: 128_000,
                    knowledgeCutoff: "2025-08",
                    strengths: ["Code generation", "Code review", "Refactoring", "Debugging"],
                    bestFor: ["Coding agents", "Code analysis", "Large-scale refactoring"],
                    toolCallSupport: .excellent,
                    japaneseSupport: .good,
                    modalities: [.text, .vision, .code],
                    pricing: .flat(inputPerMTok: 1.75, outputPerMTok: 14, cacheReadPerMTok: 0.175)
                )
            case .gpt5_4Mini:
                return ModelProfile(
                    summary: "The light 5.4: for cost-sensitive work",
                    modelFamily: "GPT",
                    description: "GPT-5.4 mini is the light variant of GPT-5.4. At $0.75 / $4.50 it fits high-throughput work.",
                    contextWindow: 400_000,
                    maxOutputTokens: 128_000,
                    knowledgeCutoff: "2025-08",
                    strengths: ["Low cost", "High throughput", "Versatility"],
                    bestFor: ["High-volume batches", "Classification", "Simple chat"],
                    toolCallSupport: .excellent,
                    japaneseSupport: .good,
                    modalities: [.text, .vision, .code],
                    pricing: .flat(inputPerMTok: 0.75, outputPerMTok: 4.50, cacheReadPerMTok: 0.075)
                )
            case .gpt5_4Nano:
                return ModelProfile(
                    summary: "Lightest and cheapest: for very high throughput",
                    modelFamily: "GPT",
                    description: "GPT-5.4 nano is the lightest model of the GPT-5.4 family. At $0.20 / $1.25, the cheapest rate of the family, it fits high-volume work where latency and cost come first.",
                    contextWindow: 400_000,
                    maxOutputTokens: 128_000,
                    knowledgeCutoff: "2025-08",
                    strengths: ["Lowest cost", "Very high throughput", "Low latency"],
                    bestFor: ["Very large batches", "Simple classification", "Light completion tasks"],
                    toolCallSupport: .excellent,
                    japaneseSupport: .good,
                    modalities: [.text, .vision, .code],
                    pricing: .flat(inputPerMTok: 0.20, outputPerMTok: 1.25, cacheReadPerMTok: 0.02)
                )
            }
        }
    }
}
