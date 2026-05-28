import Testing
@testable import LLMClient

@Suite("TokenUsage")
struct TokenUsageTests {

    @Test("freshInputTokens は cacheRead + cacheCreation を引いた値")
    func freshInput() {
        let usage = TokenUsage(
            inputTokens: 10_000,
            outputTokens: 500,
            cacheReadTokens: 7_000,
            cacheCreationTokens: 2_000
        )
        #expect(usage.freshInputTokens == 1_000)
    }

    @Test("cache 合算が input を超えた場合は 0 クランプ")
    func freshInputClamped() {
        let usage = TokenUsage(
            inputTokens: 100,
            outputTokens: 50,
            cacheReadTokens: 80,
            cacheCreationTokens: 80
        )
        #expect(usage.freshInputTokens == 0)
    }

    @Test("visibleOutputTokens は reasoning を引いた値")
    func visibleOutput() {
        let usage = TokenUsage(
            inputTokens: 100,
            outputTokens: 1_000,
            reasoningTokens: 800
        )
        #expect(usage.visibleOutputTokens == 200)
    }

    @Test("totalTokens = input + output（reasoning は output 込みなので二重計上しない）")
    func total() {
        let usage = TokenUsage(
            inputTokens: 1_000,
            outputTokens: 500,
            reasoningTokens: 300
        )
        #expect(usage.totalTokens == 1_500)
    }

    @Test("zero は全フィールド 0/nil")
    func zero() {
        let z = TokenUsage.zero
        #expect(z.inputTokens == 0)
        #expect(z.outputTokens == 0)
        #expect(z.reasoningTokens == nil)
        #expect(z.cacheReadTokens == nil)
        #expect(z.cacheCreationTokens == nil)
    }

    @Test("adding は input/output を加算、optional 値は意味のある合算")
    func adding() {
        let a = TokenUsage(inputTokens: 100, outputTokens: 50, reasoningTokens: 10, cacheReadTokens: 20)
        let b = TokenUsage(inputTokens: 200, outputTokens: 60, reasoningTokens: 5, cacheReadTokens: nil)
        let sum = a.adding(b)
        #expect(sum.inputTokens == 300)
        #expect(sum.outputTokens == 110)
        #expect(sum.reasoningTokens == 15)
        #expect(sum.cacheReadTokens == 20)
        #expect(sum.cacheTier == nil)
    }
}
