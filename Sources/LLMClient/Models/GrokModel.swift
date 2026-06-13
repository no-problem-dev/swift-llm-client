import Foundation

/// xAI Grok モデル
public enum GrokModel: Sendable, Equatable {
    /// Grok 4.3（フラッグシップ）
    case grok43

    /// Grok 4.1 Fast (Reasoning)（高速エージェント特化・推論版）
    case grok41FastReasoning

    /// Grok 4.1 Fast（高速・大量処理向け・非推論版）
    case grok41Fast

    /// Grok Build（コーディング特化ベータ）
    case grokBuild

    // MARK: Legacy（Preset 非掲載・後方互換のため保持）

    /// Grok 3（レガシー）
    case grok3

    /// Grok 3 Mini（レガシー・軽量版）
    case grok3Mini

    /// Grok 3 Fast（レガシー・高速版）
    case grok3Fast

    /// Grok 3 Mini Fast（レガシー・軽量高速版）
    case grok3MiniFast

    /// カスタムモデルID
    case custom(String)

    /// モデルID文字列を取得
    public var id: String {
        switch self {
        case .grok43:
            return "grok-4.3"
        case .grok41FastReasoning:
            return "grok-4-1-fast-reasoning"
        case .grok41Fast:
            return "grok-4-1-fast-non-reasoning"
        case .grokBuild:
            return "grok-build-0.1"
        case .grok3:
            return "grok-3"
        case .grok3Mini:
            return "grok-3-mini"
        case .grok3Fast:
            return "grok-3-fast"
        case .grok3MiniFast:
            return "grok-3-mini-fast"
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
        /// Grok 4.1 Fast (Reasoning)（高速エージェント・推論版）
        case grok41FastReasoning = "grok41FastReasoning"
        /// Grok 4.1 Fast（高速・大量処理向け・非推論版）
        case grok41Fast = "grok41Fast"
        /// Grok Build（コーディング特化ベータ）
        case grokBuild = "grokBuild"

        public var id: String { rawValue }

        /// デフォルトプリセット（フラッグシップ）
        public static let `default`: Preset = .grok43

        /// 対応する `GrokModel` を取得
        public var model: GrokModel {
            switch self {
            case .grok43: return .grok43
            case .grok41FastReasoning: return .grok41FastReasoning
            case .grok41Fast: return .grok41Fast
            case .grokBuild: return .grokBuild
            }
        }

        /// 表示名
        public var displayName: String {
            switch self {
            case .grok43: return "Grok 4.3"
            case .grok41FastReasoning: return "Grok 4.1 Fast (Reasoning)"
            case .grok41Fast: return "Grok 4.1 Fast"
            case .grokBuild: return "Grok Build"
            }
        }

        /// 短い表示名
        public var shortName: String {
            switch self {
            case .grok43: return "4.3"
            case .grok41FastReasoning: return "4.1 Fast R"
            case .grok41Fast: return "4.1 Fast"
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
            case .grok41FastReasoning:
                return ModelProfile(
                    summary: "高速エージェント特化。推論モード・200万トークン",
                    modelFamily: "Grok",
                    description: "Grok 4.1 Fast (Reasoning) は推論を有効化した高速バリアントです。200万トークンの超巨大コンテキストと優れたツール呼び出しを両立し、エージェント・高速推論用途で最良の選択肢です。",
                    contextWindow: 2_000_000,
                    knowledgeCutoff: "2024-11",
                    strengths: ["高速推論", "超巨大コンテキスト", "エージェント向き", "ツール呼び出し"],
                    bestFor: ["エージェントワークフロー", "高速な推論タスク", "大規模文脈の処理"],
                    toolCallSupport: .excellent,
                    japaneseSupport: .good,
                    modalities: [.text, .vision, .code],
                    pricing: .flat(inputPerMTok: 0.20, outputPerMTok: 0.50, cacheReadPerMTok: 0.05)
                )
            case .grok41Fast:
                return ModelProfile(
                    summary: "最安・大量処理向け。非推論・200万トークン",
                    modelFamily: "Grok",
                    description: "Grok 4.1 Fast は推論を無効化した最もコスト効率の良い Grok モデルです。200万トークンのコンテキストと低レイテンシを活かし、大量処理や高頻度な呼び出しに最適です。",
                    contextWindow: 2_000_000,
                    knowledgeCutoff: "2024-11",
                    strengths: ["最低コスト", "大量処理向き", "超巨大コンテキスト", "低レイテンシ"],
                    bestFor: ["大量バッチ処理", "高頻度な呼び出し", "汎用チャット"],
                    toolCallSupport: .excellent,
                    japaneseSupport: .good,
                    modalities: [.text, .vision, .code],
                    pricing: .flat(inputPerMTok: 0.20, outputPerMTok: 0.50, cacheReadPerMTok: 0.05)
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
