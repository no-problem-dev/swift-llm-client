import Foundation

/// Groq モデル（ホステッドモデル）
public enum GroqModel: Sendable, Equatable {
    /// GPT-OSS 120B
    case gptOss120b

    /// GPT-OSS 20B
    case gptOss20b

    /// Llama 3.3 70B Versatile
    case llama3_3_70b

    /// Qwen3 32B
    case qwen3_32b

    /// Llama 4 Scout 17B
    case llama4Scout

    /// Llama 3.1 8B Instant
    case llama3_1_8b

    /// カスタムモデルID
    case custom(String)

    /// モデルID文字列を取得
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
    /// UI選択用のプリセットモデル
    public enum Preset: String, CaseIterable, Identifiable, Codable, Sendable {
        /// GPT-OSS 120B（デフォルト）
        case gptOss120b = "gptOss120b"
        /// GPT-OSS 20B
        case gptOss20b = "gptOss20b"
        /// Llama 3.3 70B Versatile
        case llama3_3_70b = "llama3_3_70b"
        /// Qwen3 32B
        case qwen3_32b = "qwen3_32b"
        /// Llama 4 Scout 17B
        case llama4Scout = "llama4Scout"
        /// Llama 3.1 8B Instant
        case llama3_1_8b = "llama3_1_8b"

        public var id: String { rawValue }

        /// 対応する `GroqModel` を取得
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

        /// 表示名
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

        /// 短い表示名
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

        /// モデルプロファイル
        public var profile: ModelProfile {
            switch self {
            case .gptOss120b:
                return ModelProfile(
                    summary: "最高性能。ツール呼び出しに最適",
                    modelFamily: "GPT-OSS",
                    description: "GPT-OSS 120B は OpenAI のオープンウェイトモデルを Groq の高速推論エンジンで提供します。優れたツール呼び出し能力とコスト効率を両立し、エージェント用途の第一候補となります。",
                    contextWindow: 131_072,
                    maxOutputTokens: nil,
                    knowledgeCutoff: nil,
                    strengths: ["優れたツール呼び出し", "高品質推論", "コスト効率", "超高速推論"],
                    bestFor: ["ツール利用エージェント", "汎用タスク", "コード生成"],
                    toolCallSupport: .excellent,
                    japaneseSupport: .good,
                    modalities: [.text, .code],
                    pricing: .flat(inputPerMTok: 0.15, outputPerMTok: 0.60)
                )
            case .gptOss20b:
                return ModelProfile(
                    summary: "軽量高性能。低コストでツール対応",
                    modelFamily: "GPT-OSS",
                    description: "GPT-OSS 20B は OpenAI のオープンウェイトモデルを Groq で軽量・高速に実行します。優れたツール呼び出し能力を低コストで利用でき、軽量なエージェント用途に最適です。",
                    contextWindow: 131_072,
                    maxOutputTokens: nil,
                    knowledgeCutoff: nil,
                    strengths: ["優れたツール呼び出し", "軽量", "低コスト", "超高速推論"],
                    bestFor: ["軽量エージェント", "コスト重視のツール利用", "高速処理"],
                    toolCallSupport: .excellent,
                    japaneseSupport: .good,
                    modalities: [.text, .code],
                    pricing: .flat(inputPerMTok: 0.075, outputPerMTok: 0.30)
                )
            case .llama3_3_70b:
                return ModelProfile(
                    summary: "高性能 70B。バランスの良い選択",
                    modelFamily: "Llama",
                    description: "Llama 3.3 70B Versatile は高性能と汎用性のバランスに優れたモデルです。Groq の超低レイテンシ推論で高速に利用可能。",
                    contextWindow: 131_072,
                    maxOutputTokens: 32_768,
                    knowledgeCutoff: "2024-12",
                    strengths: ["汎用性", "高品質", "ツール呼び出し", "超高速推論"],
                    bestFor: ["汎用タスク", "ツール利用エージェント", "コード生成"],
                    toolCallSupport: .good,
                    japaneseSupport: .good,
                    modalities: [.text, .code],
                    pricing: .flat(inputPerMTok: 0.59, outputPerMTok: 0.79)
                )
            case .qwen3_32b:
                return ModelProfile(
                    summary: "推論特化。数学・科学に強い",
                    modelFamily: "Qwen",
                    description: "Qwen3 32B は Qwen の高性能モデルを Groq で高速実行するものです。数学・科学・論理的推論に優れ、多言語にも対応します。",
                    contextWindow: 131_072,
                    maxOutputTokens: 40_960,
                    knowledgeCutoff: nil,
                    strengths: ["推論特化", "数学・科学", "論理的思考", "高速推論"],
                    bestFor: ["数学的推論", "科学的分析", "汎用タスク"],
                    toolCallSupport: .good,
                    japaneseSupport: .good,
                    modalities: [.text, .code],
                    pricing: .flat(inputPerMTok: 0.29, outputPerMTok: 0.59)
                )
            case .llama4Scout:
                return ModelProfile(
                    summary: "最新 Llama 4。マルチモーダル対応",
                    modelFamily: "Llama",
                    description: "Llama 4 Scout 17B は Meta の最新モデルを Groq の高速推論エンジンで提供します。16 エキスパートの MoE アーキテクチャと画像入力対応により高品質な応答を実現。",
                    contextWindow: 131_072,
                    maxOutputTokens: 8_192,
                    knowledgeCutoff: "2025-03",
                    strengths: ["最新アーキテクチャ", "MoE", "マルチモーダル", "超高速推論"],
                    bestFor: ["汎用チャット", "画像理解", "高速処理"],
                    toolCallSupport: .good,
                    japaneseSupport: .good,
                    modalities: [.text, .vision, .code],
                    pricing: .flat(inputPerMTok: 0.11, outputPerMTok: 0.34)
                )
            case .llama3_1_8b:
                return ModelProfile(
                    summary: "超高速 8B。最低レイテンシ",
                    modelFamily: "Llama",
                    description: "Llama 3.1 8B Instant は最も軽量で高速なモデルです。Groq 上で最低レイテンシを実現し、シンプルなタスクに最適。",
                    contextWindow: 131_072,
                    maxOutputTokens: 8_192,
                    knowledgeCutoff: "2024-12",
                    strengths: ["超低レイテンシ", "軽量", "低コスト", "高速応答"],
                    bestFor: ["シンプルなチャット", "分類タスク", "大量バッチ処理"],
                    toolCallSupport: .basic,
                    japaneseSupport: .basic,
                    modalities: [.text, .code],
                    pricing: .flat(inputPerMTok: 0.05, outputPerMTok: 0.08)
                )
            }
        }
    }
}
