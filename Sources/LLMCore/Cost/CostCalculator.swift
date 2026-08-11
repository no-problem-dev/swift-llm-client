import Foundation

// MARK: - CostCalculator

/// Pure functions that price a request's token usage in US dollars.
public enum CostCalculator {

    /// Cost of a single request.
    ///
    /// Follows the semantics contract of the usage type, so no token is billed twice: the input
    /// count already includes the cached parts, which are split out and charged at the cache rates,
    /// and reasoning is taken out of the output before the visible-output rate applies. The price
    /// tier is chosen from the total input size, so a context-tiered model changes rate as the
    /// prompt grows. A usage with no cache tier is billed at the short-lifetime write rate.
    ///
    /// - Parameters:
    ///   - usage: Token counts reported for the request.
    ///   - pricing: Rates of the model that served it.
    public static func cost(of usage: TokenUsage, with pricing: Pricing) -> Money<USD> {
        let tier = pricing.tier(forInputTokens: usage.inputTokens)

        let cacheRead = usage.cacheReadTokens ?? 0
        let cacheCreation = usage.cacheCreationTokens ?? 0
        let fresh = usage.freshInputTokens
        let visibleOutput = usage.visibleOutputTokens
        let reasoning = usage.reasoningTokens ?? 0

        // Resolve the rates; a rate the price sheet leaves unset falls back to the tier's base rate,
        // i.e. no discount.
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
