import Foundation

// MARK: - CostCalculator

/// `TokenUsage` × `Pricing` → `Money<USD>` を計算する純関数ユーティリティ。
public enum CostCalculator {

    /// 単一ステップのコスト。
    ///
    /// `TokenUsage` のセマンティクス契約（inputTokens は cacheRead/cacheCreation を含む総量、
    /// reasoningTokens は outputTokens のサブセット）に従って、二重計上ゼロで計算する。
    public static func cost(of usage: TokenUsage, with pricing: Pricing) -> Money<USD> {
        let tier = pricing.tier(forInputTokens: usage.inputTokens)

        let cacheRead = usage.cacheReadTokens ?? 0
        let cacheCreation = usage.cacheCreationTokens ?? 0
        let fresh = usage.freshInputTokens
        let visibleOutput = usage.visibleOutputTokens
        let reasoning = usage.reasoningTokens ?? 0

        // 料率の解決: 未設定の場合は基本単価にフォールバック（= 割引なし）。
        let readRate = pricing.cacheReadPerMTok ?? tier.inputPerMTok
        let writeRate: Double = {
            switch usage.cacheTier {
            case .long:
                return pricing.cacheWriteLongPerMTok ?? tier.inputPerMTok
            case .short, .none:
                return pricing.cacheWriteShortPerMTok ?? tier.inputPerMTok
            }
        }()
        let reasoningRate = pricing.reasoningPerMTok ?? tier.outputPerMTok

        let totalPerMillion =
            Double(fresh)         * tier.inputPerMTok
            + Double(cacheRead)     * readRate
            + Double(cacheCreation) * writeRate
            + Double(visibleOutput) * tier.outputPerMTok
            + Double(reasoning)     * reasoningRate

        return Money<USD>(totalPerMillion / 1_000_000)
    }
}
