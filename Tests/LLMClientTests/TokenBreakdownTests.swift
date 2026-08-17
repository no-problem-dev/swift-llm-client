import Testing
@testable import LLMClient

/// 使ったトークンを、量と費用の 2 通りに割る。
///
/// この 2 つは食い違う。キャッシュは**量では大きいのに費用ではほぼ消える**ので、
/// 量だけを見ると直す場所を取り違える。食い違うこと自体が仕様なので、ここで固定する。
@Suite("Token Breakdown")
struct TokenBreakdownTests {

    private let pricing = Pricing.flat(
        inputPerMTok: 10,
        outputPerMTok: 100,
        cacheReadPerMTok: 1
    )

    // MARK: - 割り方

    /// 入力の総量にはキャッシュ分が含まれる(`TokenUsage` の約束)。素の入力として二重に数えない。
    @Test("キャッシュ分は入力から取り分ける")
    func cachedTokensAreTakenOutOfInput() {
        let usage = TokenUsage(
            inputTokens: 1000,
            outputTokens: 100,
            cacheReadTokens: 700,
            cacheCreationTokens: 100
        )
        let byCategory = Dictionary(
            uniqueKeysWithValues: TokenBreakdown(usage: usage).slices.map { ($0.category, $0.tokens) }
        )

        #expect(byCategory[.cacheRead] == 700)
        #expect(byCategory[.cacheWrite] == 100)
        #expect(byCategory[.input] == 200)
    }

    /// 思考は出力の内側。見えた出力として二重に数えない。
    @Test("思考は出力から取り分ける")
    func reasoningIsTakenOutOfOutput() {
        let usage = TokenUsage(inputTokens: 10, outputTokens: 100, reasoningTokens: 40)
        let byCategory = Dictionary(
            uniqueKeysWithValues: TokenBreakdown(usage: usage).slices.map { ($0.category, $0.tokens) }
        )

        #expect(byCategory[.output] == 60)
        #expect(byCategory[.reasoning] == 40)
    }

    @Test("0 の区画は出さない")
    func emptySlicesAreDropped() {
        let breakdown = TokenBreakdown(usage: TokenUsage(inputTokens: 10, outputTokens: 5))

        #expect(breakdown.slices.map(\.category) == [.input, .output])
    }

    /// 並びが変わると、同じ色が別の意味に見える。
    @Test("区画の並びはいつも同じ")
    func slicesKeepACanonicalOrder() {
        let usage = TokenUsage(
            inputTokens: 100,
            outputTokens: 100,
            reasoningTokens: 10,
            cacheReadTokens: 30,
            cacheCreationTokens: 20
        )

        #expect(
            TokenBreakdown(usage: usage).slices.map(\.category)
                == [.cacheRead, .cacheWrite, .input, .output, .reasoning]
        )
    }

    // MARK: - 費用

    /// 区画ごとの費用を足したものが、CostCalculator の答えと合う。
    /// ここがずれると、バーの割合と表示している総額が食い違う。
    @Test("区画の費用の合計は総額と一致する")
    func sliceCostsSumToTheTotal() throws {
        let usage = TokenUsage(
            inputTokens: 500_000,
            outputTokens: 200_000,
            reasoningTokens: 50_000,
            cacheReadTokens: 300_000
        )
        let breakdown = TokenBreakdown(usage: usage, pricing: pricing)

        let summed = breakdown.slices.compactMap(\.cost).reduce(Money<USD>.zero, +)
        let total = try #require(breakdown.totalCost)

        #expect(abs(summed.value - total.value) < 0.000_001)
    }

    @Test("量の割合と費用の割合は一致しない")
    func tokenSharesAndCostSharesDisagree() {
        let usage = TokenUsage(inputTokens: 1000, outputTokens: 100, cacheReadTokens: 900)
        let breakdown = TokenBreakdown(usage: usage, pricing: pricing)

        let cachedByTokens = breakdown.tokenShares.first { $0.slice.category == .cacheRead }?.share ?? 0
        let cachedByCost = breakdown.costShares.first { $0.slice.category == .cacheRead }?.share ?? 0

        #expect(cachedByTokens > 0.8)
        #expect(cachedByCost < 0.1)
    }

    @Test("料金表が無ければ費用は出さない")
    func withoutPricingThereIsNoCost() {
        let breakdown = TokenBreakdown(usage: TokenUsage(inputTokens: 10, outputTokens: 10))

        #expect(breakdown.totalCost == nil)
        #expect(breakdown.costShares.isEmpty)
        #expect(breakdown.slices.allSatisfy { $0.cost == nil })
    }

    @Test("割合は 1 に合う")
    func sharesAddUpToOne() {
        let usage = TokenUsage(
            inputTokens: 1000,
            outputTokens: 500,
            reasoningTokens: 100,
            cacheReadTokens: 400
        )
        let total = TokenBreakdown(usage: usage).tokenShares.reduce(0) { $0 + $1.share }

        #expect(abs(total - 1.0) < 0.000_001)
    }

    // MARK: - 混ぜる

    /// 1 枚の料金表でまとめて割ると、安いモデルのトークンに高いモデルの単価が当たる。
    /// モデルごとに割ってから足す。
    @Test("モデルごとに割ってから足す")
    func combiningKeepsEachModelAtItsOwnRates() {
        let expensive = Pricing.flat(inputPerMTok: 1000, outputPerMTok: 10_000)
        let usage = TokenUsage(inputTokens: 1_000_000, outputTokens: 0)

        let combined = TokenBreakdown(combining: [
            TokenBreakdown(usage: usage, pricing: pricing),   // $10
            TokenBreakdown(usage: usage, pricing: expensive), // $1000
        ])

        #expect(combined.totalCost?.value == 1010)
        #expect(combined.slices.first { $0.category == .input }?.tokens == 2_000_000)
        #expect(combined.slices.first { $0.category == .input }?.cost?.value == 1010)
    }

    /// 料金の分からないものが混ざっても、分かる分は出す。
    @Test("料金表の無い分が混ざっても分かる分は足す")
    func combiningToleratesUnpricedParts() {
        let usage = TokenUsage(inputTokens: 1_000_000, outputTokens: 0)

        let combined = TokenBreakdown(combining: [
            TokenBreakdown(usage: usage, pricing: pricing),
            TokenBreakdown(usage: usage),
        ])

        #expect(combined.slices.first { $0.category == .input }?.tokens == 2_000_000)
        #expect(combined.totalCost?.value == 10)
    }

    @Test("全部が料金表なしなら費用は出さない")
    func combiningNothingPricedStaysUnpriced() {
        let usage = TokenUsage(inputTokens: 100, outputTokens: 100)

        let combined = TokenBreakdown(combining: [
            TokenBreakdown(usage: usage),
            TokenBreakdown(usage: usage),
        ])

        #expect(combined.totalCost == nil)
    }

    /// 段が変わる料金表では、合算してから引くと段を取り違える。
    @Test("合算してから段を引き直さない")
    func combiningDoesNotRepriceAcrossTiers() {
        let tiered = Pricing(
            tiers: [
                PricingTier(upToInputTokens: 200_000, inputPerMTok: 10, outputPerMTok: 10),
                PricingTier(upToInputTokens: nil, inputPerMTok: 1000, outputPerMTok: 1000),
            ]
        )
        // 1 回 100k を 3 回。合算すると 300k で上の段に入ってしまうが、
        // 実際にはどの回も下の段で課金される。
        let step = TokenUsage(inputTokens: 100_000, outputTokens: 0)
        let combined = TokenBreakdown(combining: (0 ..< 3).map { _ in
            TokenBreakdown(usage: step, pricing: tiered)
        })

        #expect(combined.totalCost?.value == 3)
    }

    @Test("空を混ぜても落ちない")
    func combiningNothingIsEmpty() {
        let combined = TokenBreakdown(combining: [])

        #expect(combined.slices.isEmpty)
        #expect(combined.totalTokens == 0)
        #expect(combined.totalCost == nil)
    }
}
