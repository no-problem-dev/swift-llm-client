import Foundation

// MARK: - Gemini Models

/// Google Gemini モデル
///
/// ここは**アドレス**（どのモデルを指すか）の型。提供終了したモデルの case も
/// 残す — 保存済みの ID を読み戻せる必要があるため。
/// **利用者に選ばせる一覧は `Preset`**（提供中のものだけ）。
public enum GeminiModel: Sendable, Equatable {
    // MARK: - Aliases (推奨)
    case flash36
    case flash35
    case flashLite35
    case pro31Preview
    case flashLite31
    case flash3Preview

    // MARK: - Retired (2026-07 に新規利用停止。ID の読み戻し用に残す)
    case pro25
    case flash25
    case flashLite25

    // MARK: - Preview/Experimental Versions
    case flash36_version(String)
    case flash35_version(String)
    case flashLite35_version(String)
    case pro31_preview_version(String)
    case flashLite31_version(String)
    case flash3_preview_version(String)
    case pro25_version(String)
    case flash25_version(String)
    case flashLite25_version(String)

    // MARK: - Custom
    case custom(String)

    /// thinking 制御パラメータを受け付けるか。
    /// 2.5 系は `thinkingConfig.thinkingBudget`（整数）、3 系は `thinkingConfig.thinkingLevel`（文字列）を使う。
    /// 非対応モデルにこれを送るとエラーになる。
    public var supportsThinkingConfig: Bool {
        switch self {
        case .flash36, .flash35, .flashLite35, .pro31Preview, .flashLite31, .flash3Preview,
             .pro25, .flash25, .flashLite25,
             .flash36_version, .flash35_version, .flashLite35_version,
             .pro31_preview_version, .flashLite31_version, .flash3_preview_version,
             .pro25_version, .flash25_version, .flashLite25_version:
            return true
        case .custom:
            return false
        }
    }

    /// thinking のスタイル。Gemini 3 系は `thinkingLevel`、2.5 系は `thinkingBudget` を使う。
    public var thinkingControlStyle: ThinkingControlStyle {
        switch self {
        case .flash36, .flash35, .flashLite35, .pro31Preview, .flashLite31, .flash3Preview,
             .flash36_version, .flash35_version, .flashLite35_version,
             .pro31_preview_version, .flashLite31_version, .flash3_preview_version:
            return .level
        case .pro25, .flash25, .flashLite25,
             .pro25_version, .flash25_version, .flashLite25_version:
            return .budget
        case .custom:
            return .unsupported
        }
    }

    /// `thinkingLevel: minimal` を受け付けるか。
    /// Pro 3.1 と Flash-Lite 3.1 は low/medium/high のみ。Flash 系は minimal も受け付ける。
    public var supportsMinimalThinkingLevel: Bool {
        switch self {
        case .flash36, .flash35, .flash3Preview,
             .flash36_version, .flash35_version, .flash3_preview_version:
            return true
        default:
            return false
        }
    }

    /// thinking を完全に無効化できるか（thinkingBudget=0）。
    /// Gemini 2.5 Pro は不可、それ以外の 2.5 系は可。3 系は thinkingLevel 制御なので別軸（minimal が最小）。
    public var canDisableThinking: Bool {
        switch self {
        case .pro25, .pro25_version:
            return false
        case .flash25, .flashLite25, .flash25_version, .flashLite25_version:
            return true
        case .flash36, .flash35, .flashLite35, .pro31Preview, .flashLite31, .flash3Preview,
             .flash36_version, .flash35_version, .flashLite35_version,
             .pro31_preview_version, .flashLite31_version, .flash3_preview_version:
            return false  // 3 系は minimal が最小
        case .custom:
            return false
        }
    }

    /// 新規利用が停止されたモデルか。
    ///
    /// 呼ぶと 404（"no longer available to new users"）になる。ID を読み戻すために
    /// case は残してあるので、**選択肢として出す前にここで弾く**。
    public var isRetired: Bool {
        switch self {
        case .pro25, .flash25, .flashLite25,
             .pro25_version, .flash25_version, .flashLite25_version:
            return true
        default:
            return false
        }
    }

    public var id: String {
        switch self {
        case .flash36: return "gemini-3.6-flash"
        case .flash35: return "gemini-3.5-flash"
        case .flashLite35: return "gemini-3.5-flash-lite"
        case .pro31Preview: return "gemini-3.1-pro-preview"
        case .flashLite31: return "gemini-3.1-flash-lite"
        case .flash3Preview: return "gemini-3-flash-preview"
        case .pro25: return "gemini-2.5-pro"
        case .flash25: return "gemini-2.5-flash"
        case .flashLite25: return "gemini-2.5-flash-lite"
        case .flash36_version(let v): return "gemini-3.6-flash-\(v)"
        case .flash35_version(let v): return "gemini-3.5-flash-\(v)"
        case .flashLite35_version(let v): return "gemini-3.5-flash-lite-\(v)"
        case .pro31_preview_version(let v): return "gemini-3.1-pro-preview-\(v)"
        case .flashLite31_version(let v): return "gemini-3.1-flash-lite-\(v)"
        case .flash3_preview_version(let v): return "gemini-3-flash-preview-\(v)"
        case .pro25_version(let v): return "gemini-2.5-pro-\(v)"
        case .flash25_version(let v): return "gemini-2.5-flash-\(v)"
        case .flashLite25_version(let v): return "gemini-2.5-flash-lite-\(v)"
        case .custom(let id): return id
        }
    }
}

// MARK: - ThinkingControlStyle

/// Gemini モデルが受け付ける思考予算制御の種別。
public enum ThinkingControlStyle: Sendable, Hashable {
    /// `thinkingConfig.thinkingLevel`（"minimal" / "low" / "medium" / "high"）— Gemini 3 系
    case level
    /// `thinkingConfig.thinkingBudget`（整数トークン）— Gemini 2.5 系
    case budget
    /// thinking 制御非対応 — リクエストに送ってはいけない
    case unsupported
}

// MARK: - RawValue Compatibility

extension GeminiModel: RawRepresentable {
    public var rawValue: String { id }

    public init?(rawValue: String) {
        switch rawValue {
        case "gemini-3.6-flash": self = .flash36
        case "gemini-3.5-flash": self = .flash35
        case "gemini-3.5-flash-lite": self = .flashLite35
        case "gemini-3.1-pro-preview": self = .pro31Preview
        case "gemini-3.1-flash-lite": self = .flashLite31
        case "gemini-3-flash-preview": self = .flash3Preview
        case "gemini-2.5-pro": self = .pro25
        case "gemini-2.5-flash": self = .flash25
        case "gemini-2.5-flash-lite": self = .flashLite25
        default: self = .custom(rawValue)
        }
    }
}

// MARK: - Preset

/// 利用者に選ばせるモデルの一覧。
///
/// **提供中のものだけを載せる。** 提供が終わったモデルはここから外す
/// （`GeminiModel` 側の case は ID の読み戻しのために残す）。
/// 一覧に残すと選べてしまい、呼んだときに 404 になる。
extension GeminiModel {
    public enum Preset: String, CaseIterable, Identifiable, Codable, Sendable {
        case flash36 = "flash36"
        case flash35 = "flash35"
        case flashLite35 = "flashLite35"
        case pro31Preview = "pro31Preview"
        case flashLite31 = "flashLite31"
        case flash3Preview = "flash3Preview"

        public var id: String { rawValue }

        public var model: GeminiModel {
            switch self {
            case .flash36: return .flash36
            case .flash35: return .flash35
            case .flashLite35: return .flashLite35
            case .pro31Preview: return .pro31Preview
            case .flashLite31: return .flashLite31
            case .flash3Preview: return .flash3Preview
            }
        }

        public var displayName: String {
            switch self {
            case .flash36: return "Gemini 3.6 Flash"
            case .flash35: return "Gemini 3.5 Flash"
            case .flashLite35: return "Gemini 3.5 Flash-Lite"
            case .pro31Preview: return "Gemini 3.1 Pro (Preview)"
            case .flashLite31: return "Gemini 3.1 Flash-Lite"
            case .flash3Preview: return "Gemini 3 Flash (Preview)"
            }
        }

        public var shortName: String {
            switch self {
            case .flash36: return "3.6 Flash"
            case .flash35: return "3.5 Flash"
            case .flashLite35: return "3.5 Flash-Lite"
            case .pro31Preview: return "3.1 Pro"
            case .flashLite31: return "3.1 Flash-Lite"
            case .flash3Preview: return "3 Flash"
            }
        }

        public var profile: ModelProfile {
            switch self {
            case .flash36:
                return ModelProfile(
                    summary: "最新 Flash。3.5 Flash より安い出力単価",
                    modelFamily: "Gemini",
                    description: "Gemini 3.6 Flash は Google の最新 Flash GA モデル。3.5 Flash と同じ入力単価のまま出力が $9 → $7.50 に下がった。エージェント・コーディング用途の主力。",
                    contextWindow: 1_048_576,
                    maxOutputTokens: 65_536,
                    knowledgeCutoff: "2025-01",
                    strengths: ["フロンティアレベルの知性", "エージェント最適化", "高速レスポンス", "コーディング性能"],
                    bestFor: ["エージェント開発", "マルチステップワークフロー", "コーディング支援", "大量処理"],
                    toolCallSupport: .excellent,
                    japaneseSupport: .excellent,
                    modalities: [.text, .vision, .code],
                    pricing: .flat(
                        inputPerMTok: 1.50,
                        outputPerMTok: 7.50,
                        cacheReadPerMTok: 0.15
                    )
                )
            case .flashLite35:
                return ModelProfile(
                    summary: "3.5 系の軽量版。大量処理向け",
                    modelFamily: "Gemini",
                    description: "Gemini 3.5 Flash-Lite は 3.5 系の軽量・低コストモデル。3.1 Flash-Lite より単価は上がるが、より新しい世代の知性を持つ。",
                    contextWindow: 1_048_576,
                    maxOutputTokens: 65_536,
                    knowledgeCutoff: "2025-01",
                    strengths: ["低コスト", "高スループット", "エージェント最適化"],
                    bestFor: ["大量エージェントタスク", "データ抽出", "分類"],
                    toolCallSupport: .good,
                    japaneseSupport: .good,
                    modalities: [.text, .vision, .code],
                    pricing: .flat(
                        inputPerMTok: 0.30,
                        outputPerMTok: 2.50,
                        cacheReadPerMTok: 0.03
                    )
                )
            case .flash35:
                return ModelProfile(
                    summary: "最新 Flash GA。エージェント・コーディングに最強",
                    modelFamily: "Gemini",
                    description: "Gemini 3.5 Flash は Google の最新 Flash GA モデル。エージェントワークフローとコーディングタスクでフロンティアレベルの知性を発揮。高速・低コストながら長期マルチステップタスクに最適化。",
                    contextWindow: 1_048_576,
                    maxOutputTokens: 65_536,
                    knowledgeCutoff: "2025-01",
                    strengths: ["フロンティアレベルの知性", "エージェント最適化", "高速レスポンス", "コーディング性能"],
                    bestFor: ["エージェント開発", "マルチステップワークフロー", "コーディング支援", "大量処理"],
                    toolCallSupport: .excellent,
                    japaneseSupport: .excellent,
                    modalities: [.text, .vision, .code],
                    pricing: .flat(
                        inputPerMTok: 1.50,
                        outputPerMTok: 9,
                        cacheReadPerMTok: 0.15
                    )
                )
            case .pro31Preview:
                return ModelProfile(
                    summary: "最新 Pro Preview。最高品質の推論（preview 段階）",
                    modelFamily: "Gemini",
                    description: "Gemini 3.1 Pro は Google の最新 Pro モデル（preview）。100 万トークンの context、マルチモーダル入力に対応。≤200K と >200K で単価が変わる。",
                    contextWindow: 1_048_576,
                    maxOutputTokens: 65_536,
                    knowledgeCutoff: "2025-01",
                    strengths: ["超大容量コンテキスト", "マルチモーダル", "エージェント最適化", "高品質推論"],
                    bestFor: ["マルチモーダル分析", "エージェント開発", "大量ドキュメント処理"],
                    toolCallSupport: .excellent,
                    japaneseSupport: .excellent,
                    modalities: [.text, .vision, .code, .audio],
                    pricing: Pricing(
                        tiers: [
                            PricingTier(upToInputTokens: 200_000, inputPerMTok: 2, outputPerMTok: 12),
                            PricingTier(upToInputTokens: nil, inputPerMTok: 4, outputPerMTok: 18),
                        ],
                        cacheReadPerMTok: 0.20
                    )
                )
            case .flashLite31:
                return ModelProfile(
                    summary: "最速・最低コスト。高速エージェント向け",
                    modelFamily: "Gemini",
                    description: "Gemini 3.1 Flash-Lite は Gemini 3 シリーズ最速・最低コストのモデル。2.5 Flash 比で 2.5 倍高速な TTFA、45% の出力速度向上。",
                    contextWindow: 1_048_576,
                    maxOutputTokens: 65_536,
                    knowledgeCutoff: "2025-01",
                    strengths: ["最速レスポンス", "最低コスト", "高スループット", "エージェント最適化"],
                    bestFor: ["大量エージェントタスク", "データ抽出", "超低レイテンシ処理"],
                    toolCallSupport: .good,
                    japaneseSupport: .good,
                    modalities: [.text, .vision, .code],
                    pricing: .flat(
                        inputPerMTok: 0.25,
                        outputPerMTok: 1.50,
                        cacheReadPerMTok: 0.025
                    )
                )
            case .flash3Preview:
                return ModelProfile(
                    summary: "Gemini 3 Flash (preview)。Pro レベルの知性を低コストで",
                    modelFamily: "Gemini",
                    description: "Gemini 3 Flash (preview) は Pro レベルの知性を Flash の速度・コストで提供する preview モデル。思考レベルの調整が可能。",
                    contextWindow: 1_048_576,
                    maxOutputTokens: 65_536,
                    knowledgeCutoff: "2025-01",
                    strengths: ["Pro レベルの知性", "調整可能な思考レベル", "マルチモーダル", "ストリーミング関数呼び出し"],
                    bestFor: ["高スループット処理", "コスト効率重視の推論", "リアルタイムアプリケーション"],
                    toolCallSupport: .excellent,
                    japaneseSupport: .good,
                    modalities: [.text, .vision, .code],
                    pricing: .flat(
                        inputPerMTok: 0.50,
                        outputPerMTok: 3,
                        cacheReadPerMTok: 0.05
                    )
                )
            }
        }
    }
}
