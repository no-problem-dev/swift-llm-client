import Foundation

/// DeepSeek モデル
public enum DeepSeekModel: Sendable, Equatable {
    /// DeepSeek V4 Flash（コスト効率重視・デフォルト）
    case v4Flash

    /// DeepSeek V4 Pro（高性能）
    case v4Pro

    /// カスタムモデルID
    case custom(String)

    /// モデルID文字列を取得
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
    /// UI選択用のプリセットモデル
    public enum Preset: String, CaseIterable, Identifiable, Codable, Sendable {
        /// DeepSeek V4 Flash（コスト効率重視・デフォルト）
        case v4Flash = "v4Flash"
        /// DeepSeek V4 Pro（高性能）
        case v4Pro = "v4Pro"

        public var id: String { rawValue }

        /// 対応する `DeepSeekModel` を取得
        public var model: DeepSeekModel {
            switch self {
            case .v4Flash: return .v4Flash
            case .v4Pro: return .v4Pro
            }
        }

        /// 表示名
        public var displayName: String {
            switch self {
            case .v4Flash: return "DeepSeek V4 Flash"
            case .v4Pro: return "DeepSeek V4 Pro"
            }
        }

        /// 短い表示名
        public var shortName: String {
            switch self {
            case .v4Flash: return "V4 Flash"
            case .v4Pro: return "V4 Pro"
            }
        }

        /// モデルプロファイル
        public var profile: ModelProfile {
            switch self {
            case .v4Flash:
                return ModelProfile(
                    summary: "コスト効率重視。100万トークンの長文脈とツール呼び出しに対応",
                    modelFamily: "DeepSeek",
                    description: "DeepSeek V4 Flash は DeepSeek V4 世代の標準モデルです。100万トークンの長大なコンテキストウィンドウと思考モード（thinking / non-thinking の切り替え）を備え、高品質なテキスト生成・コーディング・ツール呼び出しを極めて低コストで提供します。コストを重視する幅広い日常タスクに最適です。",
                    contextWindow: 1_000_000,
                    maxOutputTokens: 384_000,
                    knowledgeCutoff: nil,
                    strengths: ["高いコスト効率", "100万トークンの長文脈", "思考モード", "ツール呼び出し", "コーディング"],
                    bestFor: ["汎用チャット", "コード生成", "長文ドキュメント処理", "コスト重視のタスク"],
                    toolCallSupport: .good,
                    japaneseSupport: .good,
                    modalities: [.text, .code],
                    pricing: .flat(inputPerMTok: 0.14, outputPerMTok: 0.28, cacheReadPerMTok: 0.0028)
                )
            case .v4Pro:
                return ModelProfile(
                    summary: "高性能。100万トークンの長文脈と深い思考、ツール呼び出しに対応",
                    modelFamily: "DeepSeek",
                    description: "DeepSeek V4 Pro は DeepSeek V4 世代の高性能モデルです。100万トークンの長大なコンテキストウィンドウと思考モード（thinking / non-thinking の切り替え）を備え、複雑な推論・高度なコーディング・ツール呼び出しで優れた性能を発揮します。品質を最優先する難易度の高いタスクに最適です。",
                    contextWindow: 1_000_000,
                    maxOutputTokens: 384_000,
                    knowledgeCutoff: nil,
                    strengths: ["高性能", "深い推論", "100万トークンの長文脈", "思考モード", "ツール呼び出し"],
                    bestFor: ["複雑な推論", "高度なコード生成", "長文ドキュメント処理", "品質重視のタスク"],
                    toolCallSupport: .good,
                    japaneseSupport: .good,
                    modalities: [.text, .code],
                    pricing: .flat(inputPerMTok: 0.435, outputPerMTok: 0.87, cacheReadPerMTok: 0.003625)
                )
            }
        }
    }
}
