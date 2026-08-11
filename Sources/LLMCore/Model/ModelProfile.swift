import Foundation

// MARK: - ModelProfile

/// What a model is like: its limits, what it can handle, and what it costs.
///
/// Covers both hosted and on-device models. Fields that only one kind has — pricing for a hosted
/// model, quantization for a local one — are optional.
public struct ModelProfile: Sendable, Hashable, Codable {

    // MARK: - Common

    /// One-line description of the model, such as "Balanced: fast and inexpensive".
    public let summary: String

    /// Family the model belongs to, such as "Claude", "Qwen" or "Gemma".
    public let modelFamily: String

    /// Parameter count as the vendor states it, such as "4B", "70B" or "30B-A3B".
    public let parameterCount: String?

    // MARK: - Detail Information

    /// Longer description of the model, which may run to several lines.
    public let description: String?

    /// Tokens the model can hold in one request, prompt and response together.
    ///
    /// A provider rejects a request that overflows it, so this is the ceiling a conversation has to
    /// stay under. Nil when the limit is not recorded for this model.
    public let contextWindow: Int?

    /// Most tokens the model will produce in one response.
    ///
    /// Asking for more is rejected, and this much of the context window has to stay free for the
    /// answer. Nil when the cap is not recorded.
    public let maxOutputTokens: Int?

    /// Month the model's training data ends. Anything later has to come from the prompt.
    public let knowledgeCutoff: YearMonth?

    /// What the model is good at, such as ["complex reasoning", "code generation"].
    public let strengths: [String]?

    /// Work the model suits, such as ["agent workflows", "code review"].
    public let bestFor: [String]?

    // MARK: - Capabilities

    /// How dependable the model is at calling tools.
    public let toolCallSupport: ToolCallSupport

    /// How well the model handles Japanese.
    public let japaneseSupport: LanguageSupport

    /// Kinds of content the model can take in or produce.
    public let modalities: Set<Modality>

    // MARK: - Cloud-specific (optional)

    /// What the model charges per token. Nil when it is not billed that way, as with a local model.
    public let pricing: Pricing?

    // MARK: - Local-specific (optional)

    /// Quantization of the local weights, such as "4bit", "QAT-4bit" or "bf16".
    public let quantization: String?

    /// Roughly how fast the model runs compared with others.
    public let inferenceSpeed: InferenceSpeed?

    public init(
        summary: String,
        modelFamily: String,
        parameterCount: String? = nil,
        description: String? = nil,
        contextWindow: Int? = nil,
        maxOutputTokens: Int? = nil,
        knowledgeCutoff: YearMonth? = nil,
        strengths: [String]? = nil,
        bestFor: [String]? = nil,
        toolCallSupport: ToolCallSupport,
        japaneseSupport: LanguageSupport,
        modalities: Set<Modality>,
        pricing: Pricing? = nil,
        quantization: String? = nil,
        inferenceSpeed: InferenceSpeed? = nil
    ) {
        self.summary = summary
        self.modelFamily = modelFamily
        self.parameterCount = parameterCount
        self.description = description
        self.contextWindow = contextWindow
        self.maxOutputTokens = maxOutputTokens
        self.knowledgeCutoff = knowledgeCutoff
        self.strengths = strengths
        self.bestFor = bestFor
        self.toolCallSupport = toolCallSupport
        self.japaneseSupport = japaneseSupport
        self.modalities = modalities
        self.pricing = pricing
        self.quantization = quantization
        self.inferenceSpeed = inferenceSpeed
    }
}

// MARK: - SupportLevel Protocol

/// A graded level of support that can be compared and sorted.
public protocol SupportLevel: RawRepresentable, Sendable, Hashable, Codable, Comparable where RawValue == String {
    /// Rank of the level; a higher number means better support, and drives the comparison operators.
    var sortOrder: Int { get }
}

extension SupportLevel {
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

// MARK: - ToolCallSupport

/// How dependable a model is at calling tools.
public enum ToolCallSupport: String, Sendable, Hashable, Codable, SupportLevel, CaseIterable {
    /// Reliable and well formed, as with Qwen3 and Claude.
    case excellent
    /// Works in most cases, as with Llama and Mistral.
    case good
    /// Limited and unreliable, as with Phi and the small Gemma models.
    case basic
    /// No tool calling at all, as with DeepSeek R1 and SmolLM.
    case unsupported

    public var sortOrder: Int {
        switch self {
        case .excellent: return 3
        case .good: return 2
        case .basic: return 1
        case .unsupported: return 0
        }
    }
}

// MARK: - LanguageSupport

/// How well a model handles a given language.
public enum LanguageSupport: String, Sendable, Hashable, Codable, SupportLevel, CaseIterable {
    /// Near-native, usually because the model was fine-tuned on the language.
    case excellent
    case good
    case basic
    case unsupported

    public var sortOrder: Int {
        switch self {
        case .excellent: return 3
        case .good: return 2
        case .basic: return 1
        case .unsupported: return 0
        }
    }
}

// MARK: - Modality

/// A kind of content a model can take in or produce.
public enum Modality: String, Sendable, Hashable, Codable {
    case text
    /// Image input, i.e. a vision-language model.
    case vision
    case audio
    /// Built for generating code.
    case code

    /// Japanese label for showing the modality in a user interface.
    public var displayName: String {
        switch self {
        case .text: return "テキスト"
        case .vision: return "画像入力（VLM）"
        case .audio: return "音声"
        case .code: return "コード生成"
        }
    }
}

// Pricing lives in Cost/Pricing.swift.

// MARK: - InferenceSpeed

/// Roughly how fast a model runs compared with others.
public enum InferenceSpeed: String, Sendable, Hashable, Codable {
    /// Fast, as small models such as LFM2 are.
    case fast
    case medium
    /// Slow, as large models are.
    case slow

    /// Japanese label for showing the speed in a user interface.
    public var displayName: String {
        switch self {
        case .fast: return "高速"
        case .medium: return "標準"
        case .slow: return "低速"
        }
    }
}
