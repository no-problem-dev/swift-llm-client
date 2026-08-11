import Foundation

/// The open-weight models Groq hosts.
public enum GroqModel: Sendable, Equatable {
    /// GPT-OSS 120B, the strongest of the hosted models and the best tool caller.
    case gptOss120b

    /// GPT-OSS 20B, with the same tool-calling strength at half the price.
    case gptOss20b

    /// Llama 3.3 70B Versatile, the balanced general-purpose choice.
    case llama3_3_70b

    /// Qwen3 32B, tuned for maths, science, and logical reasoning.
    case qwen3_32b

    /// Llama 4 Scout 17B, the only model here that takes image input.
    case llama4Scout

    /// Llama 3.1 8B Instant, the cheapest and lowest latency, with only basic tool calling.
    case llama3_1_8b

    /// An identifier passed to the API unchanged, for anything this enum does not name.
    case custom(String)

    /// The identifier sent to the API.
    public var id: String {
        switch self {
        case .gptOss120b:
            return "openai/gpt-oss-120b"
        case .gptOss20b:
            return "openai/gpt-oss-20b"
        case .llama3_3_70b:
            return "llama-3.3-70b-versatile"
        case .qwen3_32b:
            return "qwen/qwen3-32b"
        case .llama4Scout:
            return "meta-llama/llama-4-scout-17b-16e-instruct"
        case .llama3_1_8b:
            return "llama-3.1-8b-instant"
        case .custom(let id):
            return id
        }
    }
}

// MARK: - Preset

extension GroqModel {
    /// The models to put in front of a user.
    public enum Preset: String, CaseIterable, Identifiable, Codable, Sendable {
        /// GPT-OSS 120B, the strongest of the hosted models and the usual starting point.
        case gptOss120b = "gptOss120b"
        /// GPT-OSS 20B, the lighter and cheaper GPT-OSS.
        case gptOss20b = "gptOss20b"
        /// Llama 3.3 70B Versatile, the balanced general-purpose choice.
        case llama3_3_70b = "llama3_3_70b"
        /// Qwen3 32B, tuned for maths, science, and logical reasoning.
        case qwen3_32b = "qwen3_32b"
        /// Llama 4 Scout 17B, the only preset here that takes image input.
        case llama4Scout = "llama4Scout"
        /// Llama 3.1 8B Instant, the cheapest and lowest latency.
        case llama3_1_8b = "llama3_1_8b"

        public var id: String { rawValue }

        /// The model this preset names.
        public var model: GroqModel {
            switch self {
            case .gptOss120b: return .gptOss120b
            case .gptOss20b: return .gptOss20b
            case .llama3_3_70b: return .llama3_3_70b
            case .qwen3_32b: return .qwen3_32b
            case .llama4Scout: return .llama4Scout
            case .llama3_1_8b: return .llama3_1_8b
            }
        }

        public var displayName: String {
            switch self {
            case .gptOss120b: return "GPT-OSS 120B"
            case .gptOss20b: return "GPT-OSS 20B"
            case .llama3_3_70b: return "Llama 3.3 70B"
            case .qwen3_32b: return "Qwen3 32B"
            case .llama4Scout: return "Llama 4 Scout"
            case .llama3_1_8b: return "Llama 3.1 8B"
            }
        }

        /// An abbreviated label, for places too narrow for the full name.
        public var shortName: String {
            switch self {
            case .gptOss120b: return "120B"
            case .gptOss20b: return "20B"
            case .llama3_3_70b: return "70B"
            case .qwen3_32b: return "Qwen3"
            case .llama4Scout: return "Scout"
            case .llama3_1_8b: return "8B"
            }
        }

        /// Context window, pricing, and capability facts for the model.
        public var profile: ModelProfile {
            switch self {
            case .gptOss120b:
                return ModelProfile(
                    summary: "Top performance: best for tool calling",
                    modelFamily: "GPT-OSS",
                    description: "GPT-OSS 120B serves OpenAI's open-weight model on Groq's fast inference engine. It combines strong tool calling with cost efficiency, which makes it the first candidate for agent work.",
                    contextWindow: 131_072,
                    maxOutputTokens: nil,
                    knowledgeCutoff: nil,
                    strengths: ["Strong tool calling", "High-quality reasoning", "Cost efficiency", "Ultra-fast inference"],
                    bestFor: ["Tool-using agents", "General tasks", "Code generation"],
                    toolCallSupport: .excellent,
                    japaneseSupport: .good,
                    modalities: [.text, .code],
                    pricing: .flat(inputPerMTok: 0.15, outputPerMTok: 0.60)
                )
            case .gptOss20b:
                return ModelProfile(
                    summary: "Light and capable: tool calling at low cost",
                    modelFamily: "GPT-OSS",
                    description: "GPT-OSS 20B runs OpenAI's open-weight model light and fast on Groq. It puts strong tool calling within reach at low cost, which suits lightweight agent work.",
                    contextWindow: 131_072,
                    maxOutputTokens: nil,
                    knowledgeCutoff: nil,
                    strengths: ["Strong tool calling", "Lightweight", "Low cost", "Ultra-fast inference"],
                    bestFor: ["Lightweight agents", "Cost-sensitive tool use", "Fast processing"],
                    toolCallSupport: .excellent,
                    japaneseSupport: .good,
                    modalities: [.text, .code],
                    pricing: .flat(inputPerMTok: 0.075, outputPerMTok: 0.30)
                )
            case .llama3_3_70b:
                return ModelProfile(
                    summary: "A capable 70B: a well-balanced choice",
                    modelFamily: "Llama",
                    description: "Llama 3.3 70B Versatile balances capability and general usefulness well. Groq's very low latency inference makes it fast to use.",
                    contextWindow: 131_072,
                    maxOutputTokens: 32_768,
                    knowledgeCutoff: "2024-12",
                    strengths: ["Versatility", "High quality", "Tool calling", "Ultra-fast inference"],
                    bestFor: ["General tasks", "Tool-using agents", "Code generation"],
                    toolCallSupport: .good,
                    japaneseSupport: .good,
                    modalities: [.text, .code],
                    pricing: .flat(inputPerMTok: 0.59, outputPerMTok: 0.79)
                )
            case .qwen3_32b:
                return ModelProfile(
                    summary: "Reasoning specialist: strong at maths and science",
                    modelFamily: "Qwen",
                    description: "Qwen3 32B runs Qwen's high-performance model fast on Groq. It excels at maths, science, and logical reasoning, and handles many languages.",
                    contextWindow: 131_072,
                    maxOutputTokens: 40_960,
                    knowledgeCutoff: nil,
                    strengths: ["Reasoning specialist", "Maths and science", "Logical thinking", "Fast reasoning"],
                    bestFor: ["Mathematical reasoning", "Scientific analysis", "General tasks"],
                    toolCallSupport: .good,
                    japaneseSupport: .good,
                    modalities: [.text, .code],
                    pricing: .flat(inputPerMTok: 0.29, outputPerMTok: 0.59)
                )
            case .llama4Scout:
                return ModelProfile(
                    summary: "The latest Llama 4: multimodal",
                    modelFamily: "Llama",
                    description: "Llama 4 Scout 17B serves Meta's latest model on Groq's fast inference engine. A 16-expert MoE architecture and image input give it high-quality answers.",
                    contextWindow: 131_072,
                    maxOutputTokens: 8_192,
                    knowledgeCutoff: "2025-03",
                    strengths: ["Latest architecture", "MoE", "Multimodal", "Ultra-fast inference"],
                    bestFor: ["General chat", "Image understanding", "Fast processing"],
                    toolCallSupport: .good,
                    japaneseSupport: .good,
                    modalities: [.text, .vision, .code],
                    pricing: .flat(inputPerMTok: 0.11, outputPerMTok: 0.34)
                )
            case .llama3_1_8b:
                return ModelProfile(
                    summary: "A very fast 8B: the lowest latency",
                    modelFamily: "Llama",
                    description: "Llama 3.1 8B Instant is the lightest and fastest model here. It reaches the lowest latency on Groq and suits simple work.",
                    contextWindow: 131_072,
                    maxOutputTokens: 8_192,
                    knowledgeCutoff: "2024-12",
                    strengths: ["Very low latency", "Lightweight", "Low cost", "Fast responses"],
                    bestFor: ["Simple chat", "Classification tasks", "High-volume batches"],
                    toolCallSupport: .basic,
                    japaneseSupport: .basic,
                    modalities: [.text, .code],
                    pricing: .flat(inputPerMTok: 0.05, outputPerMTok: 0.08)
                )
            }
        }
    }
}
