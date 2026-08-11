import Foundation

/// The xAI Grok models.
public enum GrokModel: Sendable, Equatable {
    /// Grok 4.3, the flagship and the general-purpose choice.
    case grok43

    /// Grok 4.20 with reasoning switched on, tuned for fast agent work.
    case grok420Reasoning

    /// Grok 4.20 with reasoning switched off, for high-volume, low-latency work.
    case grok420NonReasoning

    /// Grok 4.20 tuned for several agents reasoning together on one task.
    case grok420MultiAgent

    /// Grok Build, a coding-focused beta. It has the smallest context window of the family.
    case grokBuild

    /// An identifier passed to the API unchanged, for anything this enum does not name.
    case custom(String)

    /// The identifier sent to the API.
    public var id: String {
        switch self {
        case .grok43:
            return "grok-4.3"
        case .grok420Reasoning:
            return "grok-4.20-0309-reasoning"
        case .grok420NonReasoning:
            return "grok-4.20-0309-non-reasoning"
        case .grok420MultiAgent:
            return "grok-4.20-multi-agent-0309"
        case .grokBuild:
            return "grok-build-0.1"
        case .custom(let id):
            return id
        }
    }
}

// MARK: - Preset

extension GrokModel {
    /// The models to put in front of a user.
    public enum Preset: String, CaseIterable, Identifiable, Codable, Sendable {
        /// Grok 4.3, the flagship.
        case grok43 = "grok43"
        /// Grok 4.20 with reasoning switched on.
        case grok420Reasoning = "grok420Reasoning"
        /// Grok 4.20 with reasoning switched off.
        case grok420NonReasoning = "grok420NonReasoning"
        /// Grok 4.20 tuned for several agents reasoning together.
        case grok420MultiAgent = "grok420MultiAgent"
        /// Grok Build, a coding-focused beta.
        case grokBuild = "grokBuild"

        public var id: String { rawValue }

        /// The preset to start from when the user has not chosen one.
        public static let `default`: Preset = .grok43

        /// The model this preset names.
        public var model: GrokModel {
            switch self {
            case .grok43: return .grok43
            case .grok420Reasoning: return .grok420Reasoning
            case .grok420NonReasoning: return .grok420NonReasoning
            case .grok420MultiAgent: return .grok420MultiAgent
            case .grokBuild: return .grokBuild
            }
        }

        public var displayName: String {
            switch self {
            case .grok43: return "Grok 4.3"
            case .grok420Reasoning: return "Grok 4.20 Reasoning"
            case .grok420NonReasoning: return "Grok 4.20 Fast"
            case .grok420MultiAgent: return "Grok 4.20 Multi-Agent"
            case .grokBuild: return "Grok Build"
            }
        }

        /// An abbreviated label, for places too narrow for the full name.
        public var shortName: String {
            switch self {
            case .grok43: return "4.3"
            case .grok420Reasoning: return "4.20 R"
            case .grok420NonReasoning: return "4.20 Fast"
            case .grok420MultiAgent: return "4.20 MA"
            case .grokBuild: return "Build"
            }
        }

        /// Context window, pricing, and capability facts for the model.
        public var profile: ModelProfile {
            switch self {
            case .grok43:
                return ModelProfile(
                    summary: "The xAI flagship: advanced reasoning over 1M tokens",
                    modelFamily: "Grok",
                    description: "Grok 4.3 is xAI's flagship model. It has a huge 1M-token context and top-tier reasoning, and it takes multimodal input of text and images. It is the one to reach for first on complex work.",
                    contextWindow: 1_000_000,
                    knowledgeCutoff: "2024-11",
                    strengths: ["Advanced reasoning", "Very large context", "Multimodal", "Tool calling"],
                    bestFor: ["Complex reasoning tasks", "Long-form, large-context work", "Agent workflows"],
                    toolCallSupport: .excellent,
                    japaneseSupport: .good,
                    modalities: [.text, .vision, .code],
                    pricing: .flat(inputPerMTok: 1.25, outputPerMTok: 2.50, cacheReadPerMTok: 0.20)
                )
            case .grok420Reasoning:
                return ModelProfile(
                    summary: "Fast agent specialist: reasoning mode, low hallucination",
                    modelFamily: "Grok",
                    description: "Grok 4.20 Reasoning is the fast variant with reasoning switched on. It combines strong agentic tool calling with one of the lowest hallucination rates on the market, which makes it the best choice for agents and fast reasoning.",
                    contextWindow: 1_000_000,
                    knowledgeCutoff: "2024-11",
                    strengths: ["Fast reasoning", "Agentic tool calling", "Low hallucination", "Very large context"],
                    bestFor: ["Agent workflows", "Fast reasoning tasks", "Large-context work"],
                    toolCallSupport: .excellent,
                    japaneseSupport: .good,
                    modalities: [.text, .vision, .code],
                    pricing: .flat(inputPerMTok: 1.25, outputPerMTok: 2.50, cacheReadPerMTok: 0.20)
                )
            case .grok420NonReasoning:
                return ModelProfile(
                    summary: "For high-volume work: no reasoning, low latency",
                    modelFamily: "Grok",
                    description: "Grok 4.20 Non-Reasoning is the cost-focused Grok with reasoning switched off. Its 1M-token context and low latency suit high-volume work and frequent calls.",
                    contextWindow: 1_000_000,
                    knowledgeCutoff: "2024-11",
                    strengths: ["High-volume work", "Very large context", "Low latency", "Tool calling"],
                    bestFor: ["High-volume batches", "High-frequency calls", "General chat"],
                    toolCallSupport: .excellent,
                    japaneseSupport: .good,
                    modalities: [.text, .vision, .code],
                    pricing: .flat(inputPerMTok: 1.25, outputPerMTok: 2.50, cacheReadPerMTok: 0.20)
                )
            case .grok420MultiAgent:
                return ModelProfile(
                    summary: "Multi-agent collaboration: several agents reasoning in parallel",
                    modelFamily: "Grok",
                    description: "Grok 4.20 Multi-Agent is tuned for several agents reasoning together. It splits hard work up, runs it in parallel, and merges the results, aiming past what a single agent reaches.",
                    contextWindow: 1_000_000,
                    knowledgeCutoff: "2024-11",
                    strengths: ["Multi-agent collaboration", "Hard tasks", "Very large context", "Tool calling"],
                    bestFor: ["Complex split-and-merge tasks", "Hard reasoning", "Agent workflows"],
                    toolCallSupport: .excellent,
                    japaneseSupport: .good,
                    modalities: [.text, .vision, .code],
                    pricing: .flat(inputPerMTok: 1.25, outputPerMTok: 2.50, cacheReadPerMTok: 0.20)
                )
            case .grokBuild:
                return ModelProfile(
                    summary: "Coding specialist (beta): for development work",
                    modelFamily: "Grok",
                    description: "Grok Build is a beta model specialized for coding. It is tuned for development work such as code generation, refactoring, and debugging, and it takes multimodal input as well.",
                    contextWindow: 256_000,
                    knowledgeCutoff: "2024-11",
                    strengths: ["Coding", "Refactoring", "Debugging", "Multimodal"],
                    bestFor: ["Code generation", "Refactoring", "Development assistance"],
                    toolCallSupport: .good,
                    japaneseSupport: .good,
                    modalities: [.text, .vision, .code],
                    pricing: .flat(inputPerMTok: 1.00, outputPerMTok: 2.00)
                )
            }
        }
    }
}
