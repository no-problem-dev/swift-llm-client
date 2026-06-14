import Foundation

/// xAI Grok モデル
public enum GrokModel: Sendable, Equatable {
    /// Grok 4.3（フラッグシップ・汎用推奨）
    case grok43

    /// Grok 4.20 Reasoning（高速エージェント特化・推論版）
    case grok420Reasoning

    /// Grok 4.20 Non-Reasoning（高速・大量処理向け・非推論版）
    case grok420NonReasoning

    /// Grok 4.20 Multi-Agent（マルチエージェント協調）
    case grok420MultiAgent

    /// Grok Build（コーディング特化ベータ）
    case grokBuild

    /// カスタムモデルID
    case custom(String)

    /// モデルID文字列を取得
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
    /// UI選択用のプリセットモデル
    public enum Preset: String, CaseIterable, Identifiable, Codable, Sendable {
        /// Grok 4.3（フラッグシップ・デフォルト）
        case grok43 = "grok43"
        /// Grok 4.20 Reasoning（高速エージェント・推論版）
        case grok420Reasoning = "grok420Reasoning"
        /// Grok 4.20 Non-Reasoning（高速・大量処理向け・非推論版）
        case grok420NonReasoning = "grok420NonReasoning"
        /// Grok 4.20 Multi-Agent（マルチエージェント協調）
        case grok420MultiAgent = "grok420MultiAgent"
        /// Grok Build（コーディング特化ベータ）
        case grokBuild = "grokBuild"

        public var id: String { rawValue }

        /// デフォルトプリセット（フラッグシップ）
        public static let `default`: Preset = .grok43

        /// 対応する `GrokModel` を取得
        public var model: GrokModel {
            switch self {
            case .grok43: return .grok43
            case .grok420Reasoning: return .grok420Reasoning
            case .grok420NonReasoning: return .grok420NonReasoning
            case .grok420MultiAgent: return .grok420MultiAgent
            case .grokBuild: return .grokBuild
            }
        }

        /// 表示名
        public var displayName: String {
            switch self {
            case .grok43: return "Grok 4.3"
            case .grok420Reasoning: return "Grok 4.20 Reasoning"
            case .grok420NonReasoning: return "Grok 4.20 Fast"
            case .grok420MultiAgent: return "Grok 4.20 Multi-Agent"
            case .grokBuild: return "Grok Build"
            }
        }

        /// 短い表示名
        public var shortName: String {
            switch self {
            case .grok43: return "4.3"
            case .grok420Reasoning: return "4.20 R"
            case .grok420NonReasoning: return "4.20 Fast"
            case .grok420MultiAgent: return "4.20 MA"
            case .grokBuild: return "Build"
            }
        }

        /// モデルプロファイル
        public var profile: ModelProfile {
            switch self {
            case .grok43:
                return ModelProfile(
                    summary: "xAI フラッグシップ。100万トークンの高度な推論",
                    modelFamily: "Grok",
                    description: "Grok 4.3 は xAI のフラッグシップモデルです。100万トークンの巨大なコンテキストと最高水準の推論能力を備え、マルチモーダル（テキスト・画像）入力に対応します。複雑なタスクの主力として最適です。",
                    contextWindow: 1_000_000,
                    knowledgeCutoff: "2024-11",
                    strengths: ["高度な推論", "巨大コンテキスト", "マルチモーダル", "ツール呼び出し"],
                    bestFor: ["複雑な推論タスク", "長文・大規模文脈の処理", "エージェントワークフロー"],
                    toolCallSupport: .excellent,
                    japaneseSupport: .good,
                    modalities: [.text, .vision, .code],
                    pricing: .flat(inputPerMTok: 1.25, outputPerMTok: 2.50, cacheReadPerMTok: 0.20)
                )
            case .grok420Reasoning:
                return ModelProfile(
                    summary: "高速エージェント特化。推論モード・低ハルシネーション",
                    modelFamily: "Grok",
                    description: "Grok 4.20 Reasoning は推論を有効化した高速バリアントです。強力な agentic ツール呼び出しと市場最低水準のハルシネーション率を両立し、エージェント・高速推論用途で最良の選択肢です。",
                    contextWindow: 1_000_000,
                    knowledgeCutoff: "2024-11",
                    strengths: ["高速推論", "agentic ツール呼び出し", "低ハルシネーション", "巨大コンテキスト"],
                    bestFor: ["エージェントワークフロー", "高速な推論タスク", "大規模文脈の処理"],
                    toolCallSupport: .excellent,
                    japaneseSupport: .good,
                    modalities: [.text, .vision, .code],
                    pricing: .flat(inputPerMTok: 1.25, outputPerMTok: 2.50, cacheReadPerMTok: 0.20)
                )
            case .grok420NonReasoning:
                return ModelProfile(
                    summary: "大量処理向け。非推論・低レイテンシ",
                    modelFamily: "Grok",
                    description: "Grok 4.20 Non-Reasoning は推論を無効化したコスト効率重視の Grok モデルです。100万トークンのコンテキストと低レイテンシを活かし、大量処理や高頻度な呼び出しに最適です。",
                    contextWindow: 1_000_000,
                    knowledgeCutoff: "2024-11",
                    strengths: ["大量処理向き", "巨大コンテキスト", "低レイテンシ", "ツール呼び出し"],
                    bestFor: ["大量バッチ処理", "高頻度な呼び出し", "汎用チャット"],
                    toolCallSupport: .excellent,
                    japaneseSupport: .good,
                    modalities: [.text, .vision, .code],
                    pricing: .flat(inputPerMTok: 1.25, outputPerMTok: 2.50, cacheReadPerMTok: 0.20)
                )
            case .grok420MultiAgent:
                return ModelProfile(
                    summary: "マルチエージェント協調。複数エージェントの並列推論",
                    modelFamily: "Grok",
                    description: "Grok 4.20 Multi-Agent は複数エージェントの協調推論に最適化されたモデルです。難度の高いタスクを並列に分割・統合し、単一エージェントを超える品質を狙います。",
                    contextWindow: 1_000_000,
                    knowledgeCutoff: "2024-11",
                    strengths: ["マルチエージェント協調", "高難度タスク", "巨大コンテキスト", "ツール呼び出し"],
                    bestFor: ["複雑な分割統合タスク", "高難度の推論", "エージェントワークフロー"],
                    toolCallSupport: .excellent,
                    japaneseSupport: .good,
                    modalities: [.text, .vision, .code],
                    pricing: .flat(inputPerMTok: 1.25, outputPerMTok: 2.50, cacheReadPerMTok: 0.20)
                )
            case .grokBuild:
                return ModelProfile(
                    summary: "コーディング特化ベータ。開発タスク向け",
                    modelFamily: "Grok",
                    description: "Grok Build はコーディングに特化したベータモデルです。コード生成・リファクタリング・デバッグといった開発タスクに最適化されており、マルチモーダル入力にも対応します。",
                    contextWindow: 256_000,
                    knowledgeCutoff: "2024-11",
                    strengths: ["コーディング", "リファクタリング", "デバッグ", "マルチモーダル"],
                    bestFor: ["コード生成", "リファクタリング", "開発支援"],
                    toolCallSupport: .good,
                    japaneseSupport: .good,
                    modalities: [.text, .vision, .code],
                    pricing: .flat(inputPerMTok: 1.00, outputPerMTok: 2.00)
                )
            }
        }
    }
}
