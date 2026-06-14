import Foundation

// MARK: - Pricing

/// モデルのコスト構造（USD 建て / 1M tokens）。
///
/// 通貨型は `Money<USD>` を使用し、料金単価そのものは Double で保持。
/// 計算結果のみ `Money<USD>` でラップして上位レイヤに渡す。
public struct Pricing: Sendable, Hashable, Codable {
    /// 入力サイズに応じた価格 tier（小→大の順）。
    /// 通常は 1 要素。Gemini 2.5/3.1 Pro のような context-tiered モデルで複数要素。
    public let tiers: [PricingTier]

    /// キャッシュ読み出し（hit）の単価。`nil` の場合はキャッシュ非対応モデル。
    public let cacheReadPerMTok: Double?

    /// 短期 TTL キャッシュ書込み単価。
    /// Anthropic = 5m write、OpenAI / Gemini は明示的な書込課金がないため通常 `nil`。
    public let cacheWriteShortPerMTok: Double?

    /// 長期 TTL キャッシュ書込み単価（Anthropic 1h のみ）。
    public let cacheWriteLongPerMTok: Double?

    /// reasoning トークンの単価。
    /// `nil` の場合は output と同じ単価で課金（OpenAI o-series, Gemini Flash thinking など）。
    public let reasoningPerMTok: Double?

    public init(
        tiers: [PricingTier],
        cacheReadPerMTok: Double? = nil,
        cacheWriteShortPerMTok: Double? = nil,
        cacheWriteLongPerMTok: Double? = nil,
        reasoningPerMTok: Double? = nil
    ) {
        precondition(!tiers.isEmpty, "Pricing must have at least one tier")
        precondition(
            tiers.dropLast().allSatisfy { $0.upToInputTokens != nil },
            "Only the last tier may have an unbounded upToInputTokens"
        )
        self.tiers = tiers
        self.cacheReadPerMTok = cacheReadPerMTok
        self.cacheWriteShortPerMTok = cacheWriteShortPerMTok
        self.cacheWriteLongPerMTok = cacheWriteLongPerMTok
        self.reasoningPerMTok = reasoningPerMTok
    }

    /// 単一 tier モデル用の便利初期化子。
    public static func flat(
        inputPerMTok: Double,
        outputPerMTok: Double,
        cacheReadPerMTok: Double? = nil,
        cacheWriteShortPerMTok: Double? = nil,
        cacheWriteLongPerMTok: Double? = nil,
        reasoningPerMTok: Double? = nil
    ) -> Pricing {
        Pricing(
            tiers: [PricingTier(upToInputTokens: nil,
                                inputPerMTok: inputPerMTok,
                                outputPerMTok: outputPerMTok)],
            cacheReadPerMTok: cacheReadPerMTok,
            cacheWriteShortPerMTok: cacheWriteShortPerMTok,
            cacheWriteLongPerMTok: cacheWriteLongPerMTok,
            reasoningPerMTok: reasoningPerMTok
        )
    }

    /// 与えられた入力トークン数に該当する tier を返す。
    @inlinable
    public func tier(forInputTokens tokens: Int) -> PricingTier {
        for tier in tiers {
            if let cap = tier.upToInputTokens {
                if tokens <= cap { return tier }
            } else {
                return tier
            }
        }
        return tiers.last!
    }
}

// MARK: - PricingTier

public struct PricingTier: Sendable, Hashable, Codable {
    /// この tier が適用される入力トークン数の上限（含む）。`nil` = 上限なし。
    public let upToInputTokens: Int?
    public let inputPerMTok: Double
    public let outputPerMTok: Double

    public init(upToInputTokens: Int?, inputPerMTok: Double, outputPerMTok: Double) {
        self.upToInputTokens = upToInputTokens
        self.inputPerMTok = inputPerMTok
        self.outputPerMTok = outputPerMTok
    }
}
