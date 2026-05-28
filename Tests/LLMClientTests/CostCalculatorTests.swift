import Testing
@testable import LLMClient

@Suite("CostCalculator")
struct CostCalculatorTests {

    // MARK: - Flat tier

    @Test("fresh input + output のみ（キャッシュなし）")
    func basicFlat() {
        let pricing = Pricing.flat(inputPerMTok: 3, outputPerMTok: 15)
        let usage = TokenUsage(inputTokens: 1_000_000, outputTokens: 500_000)
        let cost = CostCalculator.cost(of: usage, with: pricing)
        // 1M * $3 + 500k * $15 = $3 + $7.5 = $10.5
        #expect(abs(cost.value - 10.5) < 1e-9)
    }

    // MARK: - Cache read

    @Test("Anthropic Sonnet スタイル: cacheRead が input に含まれる")
    func anthropicCacheRead() {
        // Sonnet: input=$3 / output=$15 / cacheRead=$0.30
        let pricing = Pricing.flat(
            inputPerMTok: 3, outputPerMTok: 15,
            cacheReadPerMTok: 0.30
        )
        // inputTokens は正規化済み（cacheRead 込み総量）の前提
        let usage = TokenUsage(
            inputTokens: 100_000,
            outputTokens: 1_000,
            cacheReadTokens: 90_000,
            cacheCreationTokens: nil,
            cacheTier: .short
        )
        let cost = CostCalculator.cost(of: usage, with: pricing)
        // fresh = 10k → $3 * 0.01 = $0.03
        // cacheRead = 90k → $0.30 * 0.09 = $0.027
        // output = 1k → $15 * 0.001 = $0.015
        // total = $0.072
        #expect(abs(cost.value - 0.072) < 1e-9)
    }

    // MARK: - Cache write tiers

    @Test("Anthropic 5m vs 1h で書込料金が変わる")
    func anthropicCacheWriteTiers() {
        // Sonnet: 5m write = $3.75, 1h write = $6
        let pricing = Pricing.flat(
            inputPerMTok: 3, outputPerMTok: 15,
            cacheReadPerMTok: 0.30,
            cacheWriteShortPerMTok: 3.75,
            cacheWriteLongPerMTok: 6
        )
        let usageShort = TokenUsage(
            inputTokens: 100_000, outputTokens: 0,
            cacheCreationTokens: 100_000, cacheTier: .short
        )
        let usageLong = TokenUsage(
            inputTokens: 100_000, outputTokens: 0,
            cacheCreationTokens: 100_000, cacheTier: .long
        )
        let short = CostCalculator.cost(of: usageShort, with: pricing)
        let long = CostCalculator.cost(of: usageLong, with: pricing)
        #expect(abs(short.value - 0.375) < 1e-9)
        #expect(abs(long.value - 0.60) < 1e-9)
    }

    // MARK: - Tier-based pricing

    @Test("Gemini Pro: 200K 以下と以上で単価が変わる")
    func tieredPricing() {
        let pricing = Pricing(
            tiers: [
                PricingTier(upToInputTokens: 200_000, inputPerMTok: 2, outputPerMTok: 12),
                PricingTier(upToInputTokens: nil, inputPerMTok: 4, outputPerMTok: 18),
            ],
            cacheReadPerMTok: 0.20
        )
        // 150K input → 安い tier
        let small = TokenUsage(inputTokens: 150_000, outputTokens: 1_000)
        // 300K input → 高い tier
        let big = TokenUsage(inputTokens: 300_000, outputTokens: 1_000)
        let smallCost = CostCalculator.cost(of: small, with: pricing)
        let bigCost = CostCalculator.cost(of: big, with: pricing)
        // small: 150k * $2 + 1k * $12 = $0.3 + $0.012 = $0.312
        // big:   300k * $4 + 1k * $18 = $1.2 + $0.018 = $1.218
        #expect(abs(smallCost.value - 0.312) < 1e-9)
        #expect(abs(bigCost.value - 1.218) < 1e-9)
    }

    // MARK: - Reasoning

    @Test("OpenAI o3: reasoning は output 単価で課金される（output 込み前提でも二重計上しない）")
    func reasoningSameRateAsOutput() {
        // o3: input=$2 / output=$8 / cacheRead=$0.50
        let pricing = Pricing.flat(
            inputPerMTok: 2, outputPerMTok: 8,
            cacheReadPerMTok: 0.50
        )
        let usage = TokenUsage(
            inputTokens: 1_000,
            outputTokens: 5_000,   // OpenAI: completion_tokens は reasoning_tokens 込み
            reasoningTokens: 4_000  // → 可視出力 1k + reasoning 4k
        )
        let cost = CostCalculator.cost(of: usage, with: pricing)
        // 可視 1k * $8 + reasoning 4k * $8 + input 1k * $2 = $0.008 + $0.032 + $0.002 = $0.042
        #expect(abs(cost.value - 0.042) < 1e-9)
    }

    @Test("reasoning に別単価が設定されている場合は別単価で計算")
    func reasoningOverrideRate() {
        let pricing = Pricing.flat(
            inputPerMTok: 1, outputPerMTok: 4,
            reasoningPerMTok: 10
        )
        let usage = TokenUsage(
            inputTokens: 1_000,
            outputTokens: 2_000,
            reasoningTokens: 1_500
        )
        let cost = CostCalculator.cost(of: usage, with: pricing)
        // input 1k * $1 + visible 500 * $4 + reasoning 1500 * $10 = 0.001 + 0.002 + 0.015 = $0.018
        #expect(abs(cost.value - 0.018) < 1e-9)
    }

    // MARK: - Falls back when no pricing data

    @Test("cacheReadPerMTok 未設定なら通常 input 単価で計算（fallback、割引なし）")
    func cacheReadFallback() {
        let pricing = Pricing.flat(inputPerMTok: 3, outputPerMTok: 15)  // cache 単価なし
        let usage = TokenUsage(
            inputTokens: 100_000,
            outputTokens: 0,
            cacheReadTokens: 50_000,
            cacheTier: .short
        )
        // fresh 50k * $3 + cacheRead 50k * $3 (fallback) + output 0 = $0.30
        let cost = CostCalculator.cost(of: usage, with: pricing)
        #expect(abs(cost.value - 0.30) < 1e-9)
    }
}
