import Foundation

// MARK: - ModelProfile

/// モデルの特性・能力・コスト情報を記述する構造体
///
/// クラウド LLM とローカル LLM の両方で使用可能。
/// クラウド固有（pricing）やローカル固有（quantization）のフィールドはオプショナル。
public struct ModelProfile: Sendable, Hashable, Codable {

    // MARK: - Common

    /// モデルの一行要約（例: "高速・低コストのバランス型"）
    public let summary: String

    /// モデルファミリー名（例: "Claude", "Qwen", "Gemma"）
    public let modelFamily: String

    /// パラメータ数（例: "4B", "70B", "30B-A3B"）
    public let parameterCount: String?

    // MARK: - Capabilities

    /// ツール呼び出しのサポートレベル
    public let toolCallSupport: ToolCallSupport

    /// 日本語サポートレベル
    public let japaneseSupport: LanguageSupport

    /// サポートするモダリティ
    public let modalities: Set<Modality>

    // MARK: - Cloud-specific (optional)

    /// トークンあたりのコスト情報
    public let pricing: Pricing?

    // MARK: - Local-specific (optional)

    /// 量子化情報（例: "4bit", "QAT-4bit", "bf16"）
    public let quantization: String?

    /// 推論速度の相対的な指標
    public let inferenceSpeed: InferenceSpeed?

    public init(
        summary: String,
        modelFamily: String,
        parameterCount: String? = nil,
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
        self.toolCallSupport = toolCallSupport
        self.japaneseSupport = japaneseSupport
        self.modalities = modalities
        self.pricing = pricing
        self.quantization = quantization
        self.inferenceSpeed = inferenceSpeed
    }
}

// MARK: - ToolCallSupport

/// ツール呼び出しサポートレベル
public enum ToolCallSupport: String, Sendable, Hashable, Codable, Comparable {
    /// 高品質・安定（Qwen3, Claude）
    case excellent
    /// 大半のケースで動作（Llama, Mistral）
    case good
    /// 限定的・不安定（Phi, Gemma small）
    case basic
    /// 非対応（DeepSeek R1, SmolLM）
    case unsupported

    private var sortOrder: Int {
        switch self {
        case .excellent: return 3
        case .good: return 2
        case .basic: return 1
        case .unsupported: return 0
        }
    }

    public static func < (lhs: ToolCallSupport, rhs: ToolCallSupport) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

// MARK: - LanguageSupport

/// 言語サポートレベル
public enum LanguageSupport: String, Sendable, Hashable, Codable, Comparable {
    /// ネイティブ級・FT 済み
    case excellent
    /// 良好
    case good
    /// 基本的
    case basic
    /// 非対応
    case unsupported

    private var sortOrder: Int {
        switch self {
        case .excellent: return 3
        case .good: return 2
        case .basic: return 1
        case .unsupported: return 0
        }
    }

    public static func < (lhs: LanguageSupport, rhs: LanguageSupport) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

// MARK: - Modality

/// モダリティ
public enum Modality: String, Sendable, Hashable, Codable {
    /// テキスト
    case text
    /// 画像入力（VLM）
    case vision
    /// 音声
    case audio
    /// コード生成特化
    case code
}

// MARK: - Pricing

/// コスト情報（USD / 1M tokens）
public struct Pricing: Sendable, Hashable, Codable {
    /// 入力トークンあたりのコスト（USD/1M tokens）
    public let inputPerMTok: Double?
    /// 出力トークンあたりのコスト（USD/1M tokens）
    public let outputPerMTok: Double?
    /// キャッシュ入力トークンあたりのコスト（USD/1M tokens）
    public let cacheInputPerMTok: Double?

    public init(
        inputPerMTok: Double? = nil,
        outputPerMTok: Double? = nil,
        cacheInputPerMTok: Double? = nil
    ) {
        self.inputPerMTok = inputPerMTok
        self.outputPerMTok = outputPerMTok
        self.cacheInputPerMTok = cacheInputPerMTok
    }
}

// MARK: - InferenceSpeed

/// 推論速度の相対指標
public enum InferenceSpeed: String, Sendable, Hashable, Codable {
    /// 高速（小型モデル、LFM2 等）
    case fast
    /// 標準
    case medium
    /// 低速（大型モデル）
    case slow
}
