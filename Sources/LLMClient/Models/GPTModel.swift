import Foundation

// MARK: - GPT Models

/// OpenAI GPT モデル
///
/// ここは**アドレス**（どのモデルを指すか）の型。提供が終わった case も残す —
/// 保存済みの ID を読み戻せる必要があるため。
/// **利用者に選ばせる一覧は `Preset`**（提供中のものだけ）。
public enum GPTModel: Sendable, Equatable {
    // MARK: - Aliases (推奨)

    case gpt5_6Sol
    case gpt5_6Terra
    case gpt5_6Luna
    case gpt5_5
    case gpt5_5Pro
    case gpt5_4
    case gpt5_4Mini
    case gpt5_4Nano
    case gpt5_4Pro
    case gpt5_3Codex
    case gpt5_2Codex
    case gpt5_2
    case gpt5_1
    case gpt5
    case gpt5Mini
    case gpt5Nano
    case gpt4_1
    case gpt4_1Mini
    case gpt4_1Nano
    case gpt4o
    case gpt4oMini
    case o1
    case o1Pro
    case o3
    case o3Pro
    case o3Mini
    case o4Mini

    // MARK: - Fixed Versions

    case gpt5_6Sol_version(String)
    case gpt5_6Terra_version(String)
    case gpt5_6Luna_version(String)
    case gpt5_5_version(String)
    case gpt5_4_version(String)
    case gpt5_4Mini_version(String)
    case gpt5_4Nano_version(String)
    case gpt5_2_version(String)
    case gpt5_2Codex_version(String)
    case gpt5_1_version(String)
    case gpt5_version(String)
    case gpt5Mini_version(String)
    case gpt5Nano_version(String)
    case gpt4_1_version(String)
    case gpt4_1Mini_version(String)
    case gpt4_1Nano_version(String)
    case gpt4o_version(String)
    case gpt4oMini_version(String)
    case o1_version(String)
    case o3_version(String)
    case o3Mini_version(String)
    case o4Mini_version(String)

    // MARK: - Custom

    case custom(String)

    /// `reasoning_effort` パラメータを受け付けるか。
    /// 受け付けないモデルにこのパラメータを送るとリクエストが弾かれる。
    /// 対象: o-series (o1, o3, o3-pro, o3-mini, o4-mini) と GPT-5 系全部。
    public var supportsReasoningEffort: Bool {
        switch self {
        case .o1, .o1Pro, .o3, .o3Pro, .o3Mini, .o4Mini,
             .o1_version, .o3_version, .o3Mini_version, .o4Mini_version:
            return true
        case .gpt5_6Sol, .gpt5_6Terra, .gpt5_6Luna,
             .gpt5_5, .gpt5_5Pro, .gpt5_4, .gpt5_4Mini, .gpt5_4Nano, .gpt5_4Pro,
             .gpt5_3Codex, .gpt5_2Codex, .gpt5_2, .gpt5_1, .gpt5, .gpt5Mini, .gpt5Nano,
             .gpt5_6Sol_version, .gpt5_6Terra_version, .gpt5_6Luna_version,
             .gpt5_5_version, .gpt5_4_version, .gpt5_4Mini_version, .gpt5_4Nano_version,
             .gpt5_2_version, .gpt5_2Codex_version, .gpt5_1_version, .gpt5_version,
             .gpt5Mini_version, .gpt5Nano_version:
            return true
        case .gpt4_1, .gpt4_1Mini, .gpt4_1Nano, .gpt4o, .gpt4oMini,
             .gpt4_1_version, .gpt4_1Mini_version, .gpt4_1Nano_version,
             .gpt4o_version, .gpt4oMini_version:
            return false
        case .custom:
            return false
        }
    }

    /// `reasoning_effort` で `.minimal` を許容するか。
    ///
    /// - Warning: 名前のとおり minimal だけを見るもの。**新しく書くコードは
    ///   `supports(_:)` を使う** — minimal 以外にもモデルごとの差がある。
    @available(*, deprecated, message: "supports(_:) を使う")
    public var supportsMinimalReasoningEffort: Bool { supports(.minimal) }

    /// このモデルが受け付ける最も近い effort に丸める。
    ///
    /// 非対応の値を送るとリクエストごと弾かれるので、**落とすのではなく寄せる**。
    /// `reasoning_effort` 自体に非対応なら nil。
    ///
    /// - `max` → `xhigh` → `high`（上から順に下げる）
    /// - `none` → `minimal` → `low`（下から順に上げる）
    public func clamped(_ effort: ReasoningEffort) -> ReasoningEffort? {
        guard supportsReasoningEffort else {
            return nil
        }
        // 弱い順。指定値から「近い方へ」順に探す
        let ladder: [ReasoningEffort] = [.none, .minimal, .low, .medium, .high, .xhigh, .max]
        guard let index = ladder.firstIndex(of: effort) else {
            return nil
        }
        if supports(effort) {
            return effort
        }
        // 指定より強い側と弱い側を交互に見て、最初に対応しているものへ寄せる
        for distance in 1 ..< ladder.count {
            for candidate in [index - distance, index + distance] where ladder.indices.contains(candidate) {
                if supports(ladder[candidate]) {
                    return ladder[candidate]
                }
            }
        }
        return nil
    }

    /// この effort を受け付けるか。
    ///
    /// 受け付けない値を送るとリクエストが弾かれる（`invalid_request_error`）。
    /// 世代で使える段が違う:
    ///
    /// | 世代 | 使える effort |
    /// |---|---|
    /// | GPT-5.6 系 | none / low / medium / high / xhigh / **max** |
    /// | GPT-5.2〜5.5 | none / low / medium / high / xhigh |
    /// | GPT-5.1 | none / low / medium / high |
    /// | GPT-5 / 5.0 系 | **minimal** / low / medium / high |
    /// | o-series | low / medium / high |
    ///
    /// `minimal` は GPT-5.1 以降で `none` に置き換わった。
    public func supports(_ effort: ReasoningEffort) -> Bool {
        guard supportsReasoningEffort else {
            return false
        }
        switch effort {
        case .low, .medium, .high:
            return true
        case .minimal:
            // GPT-5.0 系のみ。o-series と 5.1 以降は none に置き換わった
            switch self {
            case .gpt5, .gpt5Mini, .gpt5Nano,
                 .gpt5_version, .gpt5Mini_version, .gpt5Nano_version:
                return true
            default:
                return false
            }
        case .none:
            // GPT-5.1 以降。o-series と GPT-5.0 系は非対応
            switch self {
            case .o1, .o1Pro, .o3, .o3Pro, .o3Mini, .o4Mini,
                 .o1_version, .o3_version, .o3Mini_version, .o4Mini_version,
                 .gpt5, .gpt5Mini, .gpt5Nano,
                 .gpt5_version, .gpt5Mini_version, .gpt5Nano_version:
                return false
            default:
                return true
            }
        case .xhigh:
            // GPT-5.2 以降
            switch self {
            case .gpt5_6Sol, .gpt5_6Terra, .gpt5_6Luna,
                 .gpt5_5, .gpt5_5Pro, .gpt5_4, .gpt5_4Mini, .gpt5_4Nano, .gpt5_4Pro,
                 .gpt5_3Codex, .gpt5_2Codex, .gpt5_2,
                 .gpt5_6Sol_version, .gpt5_6Terra_version, .gpt5_6Luna_version,
                 .gpt5_5_version, .gpt5_4_version, .gpt5_4Mini_version, .gpt5_4Nano_version,
                 .gpt5_2_version, .gpt5_2Codex_version:
                return true
            default:
                return false
            }
        case .max:
            // GPT-5.6 系のみ
            switch self {
            case .gpt5_6Sol, .gpt5_6Terra, .gpt5_6Luna,
                 .gpt5_6Sol_version, .gpt5_6Terra_version, .gpt5_6Luna_version:
                return true
            default:
                return false
            }
        }
    }

    public var id: String {
        switch self {
        case .gpt5_6Sol: return "gpt-5.6-sol"
        case .gpt5_6Terra: return "gpt-5.6-terra"
        case .gpt5_6Luna: return "gpt-5.6-luna"
        case .gpt5_5: return "gpt-5.5"
        case .gpt5_5Pro: return "gpt-5.5-pro"
        case .gpt5_4: return "gpt-5.4"
        case .gpt5_4Mini: return "gpt-5.4-mini"
        case .gpt5_4Nano: return "gpt-5.4-nano"
        case .gpt5_4Pro: return "gpt-5.4-pro"
        case .gpt5_3Codex: return "gpt-5.3-codex"
        case .gpt5_2Codex: return "gpt-5.2-codex"
        case .gpt5_2: return "gpt-5.2"
        case .gpt5_1: return "gpt-5.1"
        case .gpt5: return "gpt-5"
        case .gpt5Mini: return "gpt-5-mini"
        case .gpt5Nano: return "gpt-5-nano"
        case .gpt4_1: return "gpt-4.1"
        case .gpt4_1Mini: return "gpt-4.1-mini"
        case .gpt4_1Nano: return "gpt-4.1-nano"
        case .gpt4o: return "gpt-4o"
        case .gpt4oMini: return "gpt-4o-mini"
        case .o1: return "o1"
        case .o1Pro: return "o1-pro"
        case .o3: return "o3"
        case .o3Pro: return "o3-pro"
        case .o3Mini: return "o3-mini"
        case .o4Mini: return "o4-mini"
        case .gpt5_6Sol_version(let v): return "gpt-5.6-sol-\(v)"
        case .gpt5_6Terra_version(let v): return "gpt-5.6-terra-\(v)"
        case .gpt5_6Luna_version(let v): return "gpt-5.6-luna-\(v)"
        case .gpt5_5_version(let v): return "gpt-5.5-\(v)"
        case .gpt5_4_version(let v): return "gpt-5.4-\(v)"
        case .gpt5_4Mini_version(let v): return "gpt-5.4-mini-\(v)"
        case .gpt5_4Nano_version(let v): return "gpt-5.4-nano-\(v)"
        case .gpt5_2_version(let v): return "gpt-5.2-\(v)"
        case .gpt5_2Codex_version(let v): return "gpt-5.2-codex-\(v)"
        case .gpt5_1_version(let v): return "gpt-5.1-\(v)"
        case .gpt5_version(let v): return "gpt-5-\(v)"
        case .gpt5Mini_version(let v): return "gpt-5-mini-\(v)"
        case .gpt5Nano_version(let v): return "gpt-5-nano-\(v)"
        case .gpt4_1_version(let v): return "gpt-4.1-\(v)"
        case .gpt4_1Mini_version(let v): return "gpt-4.1-mini-\(v)"
        case .gpt4_1Nano_version(let v): return "gpt-4.1-nano-\(v)"
        case .gpt4o_version(let v): return "gpt-4o-\(v)"
        case .gpt4oMini_version(let v): return "gpt-4o-mini-\(v)"
        case .o1_version(let v): return "o1-\(v)"
        case .o3_version(let v): return "o3-\(v)"
        case .o3Mini_version(let v): return "o3-mini-\(v)"
        case .o4Mini_version(let v): return "o4-mini-\(v)"
        case .custom(let id): return id
        }
    }
}

// MARK: - Preset

/// 利用者に選ばせるモデルの一覧。
///
/// **提供中のものだけを載せる。** 提供が終わったモデルはここから外す
/// （`GPTModel` 側の case は ID の読み戻しのために残す）。
/// 一覧に残すと選べてしまい、呼んだときに 404 になる。
extension GPTModel {
    public enum Preset: String, CaseIterable, Identifiable, Codable, Sendable {
        case gpt5_6Sol = "gpt5_6Sol"
        case gpt5_6Terra = "gpt5_6Terra"
        case gpt5_6Luna = "gpt5_6Luna"
        case gpt5_3Codex = "gpt5_3Codex"
        case gpt5_4Mini = "gpt5_4Mini"
        case gpt5_4Nano = "gpt5_4Nano"

        public var id: String { rawValue }

        public var model: GPTModel {
            switch self {
            case .gpt5_6Sol: return .gpt5_6Sol
            case .gpt5_6Terra: return .gpt5_6Terra
            case .gpt5_6Luna: return .gpt5_6Luna
            case .gpt5_3Codex: return .gpt5_3Codex
            case .gpt5_4Mini: return .gpt5_4Mini
            case .gpt5_4Nano: return .gpt5_4Nano
            }
        }

        public var displayName: String {
            switch self {
            case .gpt5_6Sol: return "GPT-5.6 Sol"
            case .gpt5_6Terra: return "GPT-5.6 Terra"
            case .gpt5_6Luna: return "GPT-5.6 Luna"
            case .gpt5_3Codex: return "GPT-5.3 Codex"
            case .gpt5_4Mini: return "GPT-5.4 mini"
            case .gpt5_4Nano: return "GPT-5.4 nano"
            }
        }

        public var shortName: String {
            switch self {
            case .gpt5_6Sol: return "5.6 Sol"
            case .gpt5_6Terra: return "5.6 Terra"
            case .gpt5_6Luna: return "5.6 Luna"
            case .gpt5_3Codex: return "5.3 Codex"
            case .gpt5_4Mini: return "5.4 mini"
            case .gpt5_4Nano: return "5.4 nano"
            }
        }

        public var profile: ModelProfile {
            switch self {
            case .gpt5_6Sol:
                return ModelProfile(
                    summary: "現フラッグシップ。最も複雑な推論とエージェント",
                    modelFamily: "GPT",
                    description: "GPT-5.6 Sol は GPT-5.6 ファミリーのフロンティアモデル。最大 105 万トークンのコンテキストで、高度なコーディング・多段の計画・ツール利用に向く。272K を超える入力は入力 2 倍・出力 1.5 倍。",
                    contextWindow: 1_050_000,
                    maxOutputTokens: 128_000,
                    knowledgeCutoff: "2026-02",
                    strengths: ["最高品質の推論", "マルチモーダル", "ツール呼び出し", "エージェント性能"],
                    bestFor: ["最高品質を要する分析", "重要なエージェントタスク", "高度なコーディング"],
                    toolCallSupport: .excellent,
                    japaneseSupport: .excellent,
                    modalities: [.text, .vision, .code],
                    pricing: Pricing(
                        tiers: [
                            PricingTier(upToInputTokens: 272_000, inputPerMTok: 5, outputPerMTok: 30),
                            PricingTier(upToInputTokens: nil, inputPerMTok: 10, outputPerMTok: 45),
                        ],
                        cacheReadPerMTok: 0.50
                    )
                )
            case .gpt5_6Terra:
                return ModelProfile(
                    summary: "バランス型。知性とコストの中間",
                    modelFamily: "GPT",
                    description: "GPT-5.6 Terra は Sol と Luna の中間に位置する汎用モデル。$2 / $12 の単価で、日常のコーディング・推論・エージェント処理に広く適合する。272K を超える入力は入力 2 倍・出力 1.5 倍。",
                    contextWindow: 1_050_000,
                    maxOutputTokens: 128_000,
                    knowledgeCutoff: "2026-02",
                    strengths: ["汎用性", "コスト効率", "ツール呼び出し", "適応的推論"],
                    bestFor: ["汎用エージェント", "中規模分析", "コスト重視のプロダクション"],
                    toolCallSupport: .excellent,
                    japaneseSupport: .excellent,
                    modalities: [.text, .vision, .code],
                    pricing: Pricing(
                        tiers: [
                            PricingTier(upToInputTokens: 272_000, inputPerMTok: 2, outputPerMTok: 12),
                            PricingTier(upToInputTokens: nil, inputPerMTok: 4, outputPerMTok: 18),
                        ],
                        cacheReadPerMTok: 0.20
                    )
                )
            case .gpt5_6Luna:
                return ModelProfile(
                    summary: "最安・高スループット。大量処理向け",
                    modelFamily: "GPT",
                    description: "GPT-5.6 Luna はコスト重視・大量処理向けのモデル。$0.20 / $1.20 の単価ながら 105 万トークンのコンテキストを持ち、チャット・分類・軽量なエージェント処理に向く。272K を超える入力は入力 2 倍・出力 1.5 倍。",
                    contextWindow: 1_050_000,
                    maxOutputTokens: 128_000,
                    knowledgeCutoff: "2026-02",
                    strengths: ["最安コスト", "高スループット", "低レイテンシ", "ツール呼び出し"],
                    bestFor: ["大量バッチ", "分類", "チャット", "軽量なエージェント処理"],
                    toolCallSupport: .excellent,
                    japaneseSupport: .good,
                    modalities: [.text, .vision, .code],
                    pricing: Pricing(
                        tiers: [
                            PricingTier(upToInputTokens: 272_000, inputPerMTok: 0.20, outputPerMTok: 1.20),
                            PricingTier(upToInputTokens: nil, inputPerMTok: 0.40, outputPerMTok: 1.80),
                        ],
                        cacheReadPerMTok: 0.02
                    )
                )
            case .gpt5_3Codex:
                return ModelProfile(
                    summary: "コーディング特化。コード生成・修正に最適化",
                    modelFamily: "GPT",
                    description: "GPT-5.3 Codex は OpenAI のコーディング専用モデル。$1.75 / $14 の単価でコード生成、リファクタリング、コードレビュー、デバッグに最適化されている。",
                    contextWindow: 400_000,
                    maxOutputTokens: 128_000,
                    knowledgeCutoff: "2025-08",
                    strengths: ["コード生成", "コードレビュー", "リファクタリング", "デバッグ"],
                    bestFor: ["コーディングエージェント", "コード解析", "大規模リファクタリング"],
                    toolCallSupport: .excellent,
                    japaneseSupport: .good,
                    modalities: [.text, .vision, .code],
                    pricing: .flat(inputPerMTok: 1.75, outputPerMTok: 14, cacheReadPerMTok: 0.175)
                )
            case .gpt5_4Mini:
                return ModelProfile(
                    summary: "軽量版 5.4。コスト重視タスクに",
                    modelFamily: "GPT",
                    description: "GPT-5.4 mini は GPT-5.4 の軽量バリアント。$0.75 / $4.50 の単価で高スループットなタスクに適合する。",
                    contextWindow: 400_000,
                    maxOutputTokens: 128_000,
                    knowledgeCutoff: "2025-08",
                    strengths: ["低コスト", "高スループット", "汎用性"],
                    bestFor: ["大量バッチ", "分類", "簡易チャット"],
                    toolCallSupport: .excellent,
                    japaneseSupport: .good,
                    modalities: [.text, .vision, .code],
                    pricing: .flat(inputPerMTok: 0.75, outputPerMTok: 4.50, cacheReadPerMTok: 0.075)
                )
            case .gpt5_4Nano:
                return ModelProfile(
                    summary: "最軽量・最安。超高スループット向け",
                    modelFamily: "GPT",
                    description: "GPT-5.4 nano は GPT-5.4 ファミリーの最軽量モデル。$0.20 / $1.25 の最安単価で、レイテンシとコストを最優先する大量処理に適合する。",
                    contextWindow: 400_000,
                    maxOutputTokens: 128_000,
                    knowledgeCutoff: "2025-08",
                    strengths: ["最安コスト", "超高スループット", "低レイテンシ"],
                    bestFor: ["超大量バッチ", "簡易分類", "軽量な補完タスク"],
                    toolCallSupport: .excellent,
                    japaneseSupport: .good,
                    modalities: [.text, .vision, .code],
                    pricing: .flat(inputPerMTok: 0.20, outputPerMTok: 1.25, cacheReadPerMTok: 0.02)
                )
            }
        }
    }
}
