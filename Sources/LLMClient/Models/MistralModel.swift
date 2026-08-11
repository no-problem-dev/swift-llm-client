import Foundation

/// The Mistral AI models.
public enum MistralModel: Sendable, Equatable {
    /// Mistral Small 4, the general-purpose choice. Its 32K context is the smallest of the family.
    case small

    /// Mistral Medium 3.5, the frontier tier for agent work and coding.
    case medium

    /// Mistral Large 3, the open-weight flagship.
    case large

    /// Codestral, specialized for code, with the largest context of the family.
    case codestral

    /// Ministral 3 8B, a lightweight multimodal model priced the same for input and output.
    case ministral8b

    /// An identifier passed to the API unchanged, for anything this enum does not name.
    case custom(String)

    /// The identifier sent to the API.
    ///
    /// Four of the five are `-latest` aliases, so they follow whatever snapshot Mistral currently
    /// serves. Only Ministral 3 8B is pinned to a dated build.
    public var id: String {
        switch self {
        case .small:
            return "mistral-small-latest"
        case .medium:
            return "mistral-medium-latest"
        case .large:
            return "mistral-large-latest"
        case .codestral:
            return "codestral-latest"
        case .ministral8b:
            return "ministral-3-8b-2512"
        case .custom(let id):
            return id
        }
    }
}

// MARK: - Preset

extension MistralModel {
    /// The models to put in front of a user.
    public enum Preset: String, CaseIterable, Identifiable, Codable, Sendable {
        /// Mistral Small 4, the general-purpose choice.
        case small = "small"
        /// Mistral Medium 3.5, the frontier tier for agent work and coding.
        case medium = "medium"
        /// Mistral Large 3, the open-weight flagship.
        case large = "large"
        /// Codestral, specialized for code.
        case codestral = "codestral"
        /// Ministral 3 8B, a lightweight multimodal model.
        case ministral8b = "ministral8b"

        public var id: String { rawValue }

        /// The model this preset names.
        public var model: MistralModel {
            switch self {
            case .small: return .small
            case .medium: return .medium
            case .large: return .large
            case .codestral: return .codestral
            case .ministral8b: return .ministral8b
            }
        }

        public var displayName: String {
            switch self {
            case .small: return "Mistral Small 4"
            case .medium: return "Mistral Medium 3.5"
            case .large: return "Mistral Large 3"
            case .codestral: return "Codestral"
            case .ministral8b: return "Ministral 3 8B"
            }
        }

        /// An abbreviated label, for places too narrow for the full name.
        public var shortName: String {
            switch self {
            case .small: return "Small 4"
            case .medium: return "Medium 3.5"
            case .large: return "Large 3"
            case .codestral: return "Codestral"
            case .ministral8b: return "Ministral 8B"
            }
        }

        /// Context window, pricing, and capability facts for the model.
        public var profile: ModelProfile {
            switch self {
            case .small:
                return ModelProfile(
                    summary: "The general-purpose default: a reasoning and coding hybrid",
                    modelFamily: "Mistral",
                    description: "Mistral Small 4 is a hybrid model that brings instruct, reasoning, and coding together. It is inexpensive yet broadly capable, which makes it a general-purpose default for high-volume work and real-time apps. It takes text, images, and code.",
                    contextWindow: 32_000,
                    maxOutputTokens: 8_192,
                    knowledgeCutoff: "2025-01",
                    strengths: ["Hybrid reasoning", "Cost efficiency", "Multilingual", "Multimodal"],
                    bestFor: ["General-purpose default", "Classification and summarization", "High-volume batches"],
                    toolCallSupport: .good,
                    japaneseSupport: .good,
                    modalities: [.text, .vision, .code],
                    pricing: .flat(inputPerMTok: 0.10, outputPerMTok: 0.30)
                )
            case .medium:
                return ModelProfile(
                    summary: "Frontier tier: specialized for agents and coding",
                    modelFamily: "Mistral",
                    description: "Mistral Medium 3.5 is a frontier model specialized for agent workflows and advanced coding. It executes accurately across complex tool integrations and multi-step work, and it takes text, images, and code.",
                    contextWindow: 128_000,
                    maxOutputTokens: 8_192,
                    knowledgeCutoff: "2025-01",
                    strengths: ["Agent execution", "Advanced coding", "Tool integration", "Multimodal"],
                    bestFor: ["Agent workflows", "Code generation", "Complex task automation"],
                    toolCallSupport: .excellent,
                    japaneseSupport: .good,
                    modalities: [.text, .vision, .code],
                    pricing: .flat(inputPerMTok: 1.50, outputPerMTok: 7.50)
                )
            case .large:
                return ModelProfile(
                    summary: "The open-weight flagship MoE",
                    modelFamily: "Mistral",
                    description: "Mistral Large 3 is the open-weight flagship, a Mixture-of-Experts model. It excels at complex reasoning, multi-step analysis, and advanced code generation, and it takes text, images, and code.",
                    contextWindow: 128_000,
                    maxOutputTokens: 8_192,
                    knowledgeCutoff: "2025-01",
                    strengths: ["Advanced reasoning", "MoE architecture", "Coding", "Multimodal"],
                    bestFor: ["Complex reasoning", "Code generation", "Multilingual tasks"],
                    toolCallSupport: .excellent,
                    japaneseSupport: .good,
                    modalities: [.text, .vision, .code],
                    pricing: .flat(inputPerMTok: 0.50, outputPerMTok: 1.50)
                )
            case .codestral:
                return ModelProfile(
                    summary: "Coding specialist: 80+ languages",
                    modelFamily: "Mistral",
                    description: "Codestral is Mistral's coding specialist. It covers more than 80 programming languages and is built for code generation, completion, and refactoring.",
                    contextWindow: 256_000,
                    maxOutputTokens: 8_192,
                    knowledgeCutoff: "2025-01",
                    strengths: ["Coding specialist", "80+ languages", "Code completion", "Refactoring"],
                    bestFor: ["Code generation", "Code review", "Refactoring"],
                    toolCallSupport: .good,
                    japaneseSupport: .basic,
                    modalities: [.text, .code],
                    pricing: .flat(inputPerMTok: 0.30, outputPerMTok: 0.90)
                )
            case .ministral8b:
                return ModelProfile(
                    summary: "Lightweight multimodal: cheap and fast",
                    modelFamily: "Mistral",
                    description: "Ministral 3 8B is a lightweight multimodal model that handles text, images, and code cheaply and quickly. It suits edge-leaning use cases and high-volume work, and its flat input and output price keeps it easy to reason about.",
                    contextWindow: 128_000,
                    maxOutputTokens: 8_192,
                    knowledgeCutoff: nil,
                    strengths: ["Lightweight multimodal", "Fast", "Low cost", "Function calling"],
                    bestFor: ["Lightweight chat", "Lightweight classification", "High-volume work"],
                    toolCallSupport: .good,
                    japaneseSupport: .basic,
                    modalities: [.text, .vision, .code],
                    pricing: .flat(inputPerMTok: 0.15, outputPerMTok: 0.15)
                )
            }
        }
    }
}
