import Foundation

/// The DeepSeek models.
public enum DeepSeekModel: Sendable, Equatable {
    /// DeepSeek V4 Flash, the cost-efficient default and the cheaper of the two.
    case v4Flash

    /// DeepSeek V4 Pro, the higher-performance tier at roughly three times the price.
    case v4Pro

    /// An identifier passed to the API unchanged, for anything this enum does not name.
    case custom(String)

    /// The identifier sent to the API.
    public var id: String {
        switch self {
        case .v4Flash:
            return "deepseek-v4-flash"
        case .v4Pro:
            return "deepseek-v4-pro"
        case .custom(let id):
            return id
        }
    }
}

// MARK: - Preset

extension DeepSeekModel {
    /// The models to put in front of a user.
    public enum Preset: String, CaseIterable, Identifiable, Codable, Sendable {
        /// DeepSeek V4 Flash, the cost-efficient default.
        case v4Flash = "v4Flash"
        /// DeepSeek V4 Pro, the higher-performance tier.
        case v4Pro = "v4Pro"

        public var id: String { rawValue }

        /// The model this preset names.
        public var model: DeepSeekModel {
            switch self {
            case .v4Flash: return .v4Flash
            case .v4Pro: return .v4Pro
            }
        }

        public var displayName: String {
            switch self {
            case .v4Flash: return "DeepSeek V4 Flash"
            case .v4Pro: return "DeepSeek V4 Pro"
            }
        }

        /// An abbreviated label, for places too narrow for the full name.
        public var shortName: String {
            switch self {
            case .v4Flash: return "V4 Flash"
            case .v4Pro: return "V4 Pro"
            }
        }

        /// Context window, pricing, and capability facts for the model.
        public var profile: ModelProfile {
            switch self {
            case .v4Flash:
                return ModelProfile(
                    summary: "Cost-efficient: a 1M-token context and tool calling",
                    modelFamily: "DeepSeek",
                    description: "DeepSeek V4 Flash is the standard model of the DeepSeek V4 generation. It has a 1M-token context window and a thinking mode that switches between thinking and non-thinking, and it delivers high-quality text generation, coding, and tool calling at very low cost. It suits a wide range of everyday work where cost matters.",
                    contextWindow: 1_000_000,
                    maxOutputTokens: 384_000,
                    knowledgeCutoff: nil,
                    strengths: ["Strong cost efficiency", "1M-token context", "Thinking mode", "Tool calling", "Coding"],
                    bestFor: ["General chat", "Code generation", "Long document processing", "Cost-sensitive tasks"],
                    toolCallSupport: .good,
                    japaneseSupport: .good,
                    modalities: [.text, .code],
                    pricing: .flat(inputPerMTok: 0.14, outputPerMTok: 0.28, cacheReadPerMTok: 0.0028)
                )
            case .v4Pro:
                return ModelProfile(
                    summary: "High performance: a 1M-token context, deep thinking, and tool calling",
                    modelFamily: "DeepSeek",
                    description: "DeepSeek V4 Pro is the high-performance model of the DeepSeek V4 generation. It has a 1M-token context window and a thinking mode that switches between thinking and non-thinking, and it performs well on complex reasoning, advanced coding, and tool calling. It suits demanding work where quality comes first.",
                    contextWindow: 1_000_000,
                    maxOutputTokens: 384_000,
                    knowledgeCutoff: nil,
                    strengths: ["High performance", "Deep reasoning", "1M-token context", "Thinking mode", "Tool calling"],
                    bestFor: ["Complex reasoning", "Advanced code generation", "Long document processing", "Quality-first tasks"],
                    toolCallSupport: .good,
                    japaneseSupport: .good,
                    modalities: [.text, .code],
                    pricing: .flat(inputPerMTok: 0.435, outputPerMTok: 0.87, cacheReadPerMTok: 0.003625)
                )
            }
        }
    }
}
