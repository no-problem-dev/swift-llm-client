import Testing
@testable import LLMClient

@Suite("ContextOccupancy")
struct ContextOccupancyTests {

    // MARK: - T1-1: 基本占有

    @Test("usage + windowSize から used / free / usedFraction を算出")
    func basicOccupancy() {
        let usage = TokenUsage(inputTokens: 142_000, outputTokens: 500)
        let occ = ContextOccupancy(usage: usage, windowSize: 1_000_000)

        #expect(occ.used == 142_000)
        #expect(occ.promptTokens == 142_000)
        #expect(occ.free == 1_000_000 - 142_000) // reserve/buffer 既定 0
        #expect(occ.usedFraction.map { abs($0 - 0.142) < 1e-9 } == true)
        #expect(occ.isOverLimit == false)
    }

    @Test("outputReserve / compactionBuffer は free のみを縮める（used は不変）")
    func reserveShrinksFreeOnly() {
        let usage = TokenUsage(inputTokens: 100_000, outputTokens: 0)
        let occ = ContextOccupancy(
            usage: usage, windowSize: 200_000,
            outputReserve: 64_000, compactionBuffer: 16_000
        )
        #expect(occ.used == 100_000)
        #expect(occ.free == 200_000 - 100_000 - 64_000 - 16_000) // = 20_000
        #expect(occ.usedFraction.map { abs($0 - 0.5) < 1e-9 } == true) // 100k/200k
    }

    // MARK: - T1-2: cached / fresh 内訳

    @Test("cacheRead/cacheCreation は promptTokens のサブセット、fresh は差分")
    func cachedFreshBreakdown() {
        // Anthropic スタイル: inputTokens は cache 込み総量に正規化済
        let usage = TokenUsage(
            inputTokens: 120_000, outputTokens: 800,
            cacheReadTokens: 90_000, cacheCreationTokens: 10_000
        )
        let occ = ContextOccupancy(usage: usage, windowSize: 1_000_000)

        #expect(occ.cacheReadTokens == 90_000)
        #expect(occ.cacheCreationTokens == 10_000)
        #expect(occ.freshInputTokens == 120_000 - 90_000 - 10_000) // = 20_000
        // cached も占有: used は総量、cache を差し引かない
        #expect(occ.used == 120_000)
    }

    // MARK: - T1-3: エッジケース

    @Test("windowSize == nil → free / usedFraction は nil（絶対値のみ表示にフォールバック）")
    func unknownWindowYieldsNil() {
        let usage = TokenUsage(inputTokens: 50_000, outputTokens: 0)
        let occ = ContextOccupancy(usage: usage, windowSize: nil)

        #expect(occ.used == 50_000)
        #expect(occ.free == nil)
        #expect(occ.usedFraction == nil)
        #expect(occ.isOverLimit == false)
    }

    @Test("超過時は free を 0 にクランプし isOverLimit が true")
    func overLimitClampsFree() {
        let usage = TokenUsage(inputTokens: 250_000, outputTokens: 0)
        let occ = ContextOccupancy(usage: usage, windowSize: 200_000)

        #expect(occ.isOverLimit == true)
        #expect(occ.free == 0)
        #expect(occ.usedFraction.map { $0 > 1.0 } == true)
    }

    @Test("reserve が残容量を超えても free は負にならず 0")
    func reserveExceedsRemaining() {
        let usage = TokenUsage(inputTokens: 180_000, outputTokens: 0)
        let occ = ContextOccupancy(
            usage: usage, windowSize: 200_000,
            outputReserve: 64_000
        )
        #expect(occ.free == 0) // 200k - 180k - 64k = -44k → 0 クランプ
    }

    // MARK: - ModelProfile 便利初期化

    @Test("ModelProfile から windowSize と outputReserve(=maxOutputTokens) を解決")
    func deriveFromProfile() {
        let profile = ModelProfile(
            summary: "test", modelFamily: "Test",
            contextWindow: 200_000, maxOutputTokens: 64_000,
            toolCallSupport: .excellent, japaneseSupport: .excellent, modalities: [.text]
        )
        let usage = TokenUsage(inputTokens: 100_000, outputTokens: 0)
        let occ = ContextOccupancy(usage: usage, profile: profile)

        #expect(occ.windowSize == 200_000)
        #expect(occ.outputReserve == 64_000) // = maxOutputTokens
        #expect(occ.free == 200_000 - 100_000 - 64_000) // = 36_000
    }

    @Test("used/windowSize 初期化（ACP usage_update 由来）")
    func usedWindowInit() {
        let occ = ContextOccupancy(used: 142_000, windowSize: 1_000_000)
        #expect(occ.used == 142_000)
        #expect(occ.freshInputTokens == 142_000)
        #expect(occ.cacheReadTokens == 0)
        #expect(occ.free == 1_000_000 - 142_000)
        #expect(occ.usedFraction.map { abs($0 - 0.142) < 1e-9 } == true)
    }

    // MARK: - T1-4: ACP マッピング

    @Test("ACP usage_update: used == promptTokens, windowSize == size")
    func acpMapping() {
        let usage = TokenUsage(inputTokens: 75_000, outputTokens: 0)
        let occ = ContextOccupancy(usage: usage, windowSize: 1_000_000)
        // usage_update { used, size }
        #expect(occ.used == 75_000)
        #expect(occ.windowSize == 1_000_000)
    }
}
