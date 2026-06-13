import Foundation

/// Mistral AI モデル
public enum MistralModel: Sendable, Equatable {
    /// Mistral Small 4（一般用途デフォルト）
    case small

    /// Mistral Medium 3.5（フロンティア・エージェント/コーディング）
    case medium

    /// Mistral Large 3（オープンウェイト・フラッグシップ）
    case large

    /// Codestral（コーディング特化）
    case codestral

    /// Ministral 3 8B（軽量マルチモーダル）
    case ministral8b

    /// カスタムモデルID
    case custom(String)

    /// モデルID文字列を取得
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
    /// UI選択用のプリセットモデル
    public enum Preset: String, CaseIterable, Identifiable, Codable, Sendable {
        /// Mistral Small 4（一般用途デフォルト）
        case small = "small"
        /// Mistral Medium 3.5（フロンティア・エージェント/コーディング）
        case medium = "medium"
        /// Mistral Large 3（オープンウェイト・フラッグシップ）
        case large = "large"
        /// Codestral（コーディング特化）
        case codestral = "codestral"
        /// Ministral 3 8B（軽量マルチモーダル）
        case ministral8b = "ministral8b"

        public var id: String { rawValue }

        /// 対応する `MistralModel` を取得
        public var model: MistralModel {
            switch self {
            case .small: return .small
            case .medium: return .medium
            case .large: return .large
            case .codestral: return .codestral
            case .ministral8b: return .ministral8b
            }
        }

        /// 表示名
        public var displayName: String {
            switch self {
            case .small: return "Mistral Small 4"
            case .medium: return "Mistral Medium 3.5"
            case .large: return "Mistral Large 3"
            case .codestral: return "Codestral"
            case .ministral8b: return "Ministral 3 8B"
            }
        }

        /// 短い表示名
        public var shortName: String {
            switch self {
            case .small: return "Small 4"
            case .medium: return "Medium 3.5"
            case .large: return "Large 3"
            case .codestral: return "Codestral"
            case .ministral8b: return "Ministral 8B"
            }
        }

        /// モデルプロファイル
        public var profile: ModelProfile {
            switch self {
            case .small:
                return ModelProfile(
                    summary: "一般用途デフォルト。推論+コーディングのハイブリッド",
                    modelFamily: "Mistral",
                    description: "Mistral Small 4 は instruct・推論・コーディングを統合したハイブリッドモデルです。低コストながら高い汎用性能を発揮し、一般用途のデフォルトとして大量処理やリアルタイムアプリケーションに適しています。マルチモーダル（テキスト・画像・コード）に対応します。",
                    contextWindow: 32_000,
                    maxOutputTokens: 8_192,
                    knowledgeCutoff: "2025-01",
                    strengths: ["ハイブリッド推論", "コスト効率", "多言語対応", "マルチモーダル"],
                    bestFor: ["一般用途デフォルト", "分類・要約", "大量バッチ処理"],
                    toolCallSupport: .good,
                    japaneseSupport: .good,
                    modalities: [.text, .vision, .code],
                    pricing: .flat(inputPerMTok: 0.10, outputPerMTok: 0.30)
                )
            case .medium:
                return ModelProfile(
                    summary: "フロンティア・エージェント/コーディング特化",
                    modelFamily: "Mistral",
                    description: "Mistral Medium 3.5 はエージェントワークフローと高度なコーディングに特化したフロンティアモデルです。複雑なツール連携や多段階タスクで高い実行精度を発揮し、マルチモーダル（テキスト・画像・コード）に対応します。",
                    contextWindow: 128_000,
                    maxOutputTokens: 8_192,
                    knowledgeCutoff: "2025-01",
                    strengths: ["エージェント実行", "高度なコーディング", "ツール連携", "マルチモーダル"],
                    bestFor: ["エージェントワークフロー", "コード生成", "複雑なタスク自動化"],
                    toolCallSupport: .excellent,
                    japaneseSupport: .good,
                    modalities: [.text, .vision, .code],
                    pricing: .flat(inputPerMTok: 1.50, outputPerMTok: 7.50)
                )
            case .large:
                return ModelProfile(
                    summary: "オープンウェイト・フラッグシップ MoE",
                    modelFamily: "Mistral",
                    description: "Mistral Large 3 はオープンウェイトのフラッグシップ MoE（Mixture-of-Experts）モデルです。複雑な推論、多段階分析、高度なコード生成に優れ、マルチモーダル（テキスト・画像・コード）に対応します。",
                    contextWindow: 128_000,
                    maxOutputTokens: 8_192,
                    knowledgeCutoff: "2025-01",
                    strengths: ["高度な推論", "MoE アーキテクチャ", "コーディング", "マルチモーダル"],
                    bestFor: ["複雑な推論", "コード生成", "多言語タスク"],
                    toolCallSupport: .excellent,
                    japaneseSupport: .good,
                    modalities: [.text, .vision, .code],
                    pricing: .flat(inputPerMTok: 0.50, outputPerMTok: 1.50)
                )
            case .codestral:
                return ModelProfile(
                    summary: "コーディング特化。80+ 言語対応",
                    modelFamily: "Mistral",
                    description: "Codestral は Mistral のコーディング特化モデルです。80 以上のプログラミング言語に対応し、コード生成・補完・リファクタリングに特化しています。",
                    contextWindow: 256_000,
                    maxOutputTokens: 8_192,
                    knowledgeCutoff: "2025-01",
                    strengths: ["コーディング特化", "80+ 言語", "コード補完", "リファクタリング"],
                    bestFor: ["コード生成", "コードレビュー", "リファクタリング"],
                    toolCallSupport: .good,
                    japaneseSupport: .basic,
                    modalities: [.text, .code],
                    pricing: .flat(inputPerMTok: 0.30, outputPerMTok: 0.90)
                )
            case .ministral8b:
                return ModelProfile(
                    summary: "軽量マルチモーダル。低コスト・高速",
                    modelFamily: "Mistral",
                    description: "Ministral 3 8B は軽量なマルチモーダルモデルで、低コスト・高速にテキスト・画像・コードを処理します。エッジ寄りのユースケースや大量処理に適し、入出力が均一価格で扱いやすいモデルです。",
                    contextWindow: 128_000,
                    maxOutputTokens: 8_192,
                    knowledgeCutoff: nil,
                    strengths: ["軽量マルチモーダル", "高速", "低コスト", "関数呼び出し"],
                    bestFor: ["軽量チャット", "軽量な分類", "大量処理"],
                    toolCallSupport: .good,
                    japaneseSupport: .basic,
                    modalities: [.text, .vision, .code],
                    pricing: .flat(inputPerMTok: 0.15, outputPerMTok: 0.15)
                )
            }
        }
    }
}
